#include <metal_stdlib>
using namespace metal;

float2 direction_to_uv(float3 dir) {
    float phi = atan2(dir.z, dir.x);
    float theta = acos(dir.y);
    return float2(phi / (2.0 * M_PI_F) + 0.5, theta / M_PI_F);
}

float3 face_uv_to_direction(uint face, float2 uv) {
    float u = uv.x * 2.0 - 1.0;
    float v = uv.y * 2.0 - 1.0;
    switch (face) {
        case 0: return float3( 1.0,  v,   -u);
        case 1: return float3(-1.0,  v,    u);
        case 2: return float3(  u,  1.0,  -v);
        case 3: return float3(  u, -1.0,   v);
        case 4: return float3(  u,   v,   1.0);
        default: return float3( -u,   v,  -1.0);
    }
}

float radical_inverse_vdc(uint bits) {
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10;
}

float2 hammersley(uint i, uint N) {
    return float2(float(i) / float(N), radical_inverse_vdc(i));
}

float3 importance_sample_ggx(float2 xi, float3 N, float roughness) {
    float a = roughness * roughness;
    float phi = 2.0 * M_PI_F * xi.x;
    float cosTheta = sqrt((1.0 - xi.y) / (1.0 + (a * a - 1.0) * xi.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

    float3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;

    float3 up = abs(N.z) < 0.999 ? float3(0.0, 0.0, 1.0) : float3(1.0, 0.0, 0.0);
    float3 tangent = normalize(cross(up, N));
    float3 bitangent = cross(N, tangent);

    float3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
}

float geometry_schlick_ggx_ibl(float NdotV, float roughness) {
    float a = roughness;
    float k = (a * a) / 2.0;
    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    return nom / denom;
}

float geometry_smith_ibl(float3 N, float3 V, float3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    return geometry_schlick_ggx_ibl(NdotV, roughness) * geometry_schlick_ggx_ibl(NdotL, roughness);
}

kernel void irradiance_map(
    texture2d<float, access::sample> equirect [[texture(0)]],
    texturecube<float, access::write> outputMap [[texture(1)]],
    uint3 tid [[thread_position_in_grid]]
) {
    uint face = tid.x;
    float2 uv = (float2(tid.y, tid.z) + 0.5) / float2(outputMap.get_width(), outputMap.get_height());
    float3 N = normalize(face_uv_to_direction(face, uv));

    float3 up = abs(N.y) < 0.999 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
    float3 right = normalize(cross(up, N));
    up = cross(N, right);

    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float sampleDelta = 0.025;
    float nrSamples = 0.0;
    float3 color = float3(0.0);

    for (float phi = 0.0; phi < 2.0 * M_PI_F; phi += sampleDelta) {
        for (float theta = 0.0; theta < 0.5 * M_PI_F; theta += sampleDelta) {
            float3 tangentSample = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
            float3 sampleVec = tangentSample.x * right + tangentSample.y * up + tangentSample.z * N;
            float2 eqUV = direction_to_uv(sampleVec);
            color += equirect.sample(s, eqUV).rgb * cos(theta) * sin(theta);
            nrSamples += 1.0;
        }
    }

    color = M_PI_F * color / nrSamples;
    outputMap.write(float4(color, 1.0), tid.yz, face);
}

kernel void prefilter_envmap(
    texture2d<float, access::sample> equirect [[texture(0)]],
    texturecube<float, access::write> outputMap [[texture(1)]],
    constant float& roughness [[buffer(0)]],
    uint3 tid [[thread_position_in_grid]]
) {
    uint face = tid.x;
    float2 uv = (float2(tid.y, tid.z) + 0.5) / float2(outputMap.get_width(), outputMap.get_height());
    float3 N = normalize(face_uv_to_direction(face, uv));
    float3 R = N;
    float3 V = R;

    constexpr sampler s(filter::linear, address::clamp_to_edge);

    uint SAMPLE_COUNT = 1024u;
    float totalWeight = 0.0;
    float3 prefilteredColor = float3(0.0);

    for (uint i = 0; i < SAMPLE_COUNT; i++) {
        float2 xi = hammersley(i, SAMPLE_COUNT);
        float3 H = importance_sample_ggx(xi, N, roughness);
        float3 L = normalize(2.0 * dot(V, H) * H - V);

        float NdotL = max(dot(N, L), 0.0);
        if (NdotL > 0.0) {
            float2 eqUV = direction_to_uv(L);
            prefilteredColor += equirect.sample(s, eqUV).rgb * NdotL;
            totalWeight += NdotL;
        }
    }

    prefilteredColor = prefilteredColor / max(totalWeight, 0.001);
    outputMap.write(float4(prefilteredColor, 1.0), tid.yz, face);
}

kernel void brdf_integration(
    texture2d<float, access::write> lut [[texture(0)]],
    uint2 tid [[thread_position_in_grid]]
) {
    float width = float(lut.get_width());
    float height = float(lut.get_height());
    float NdotV = (float(tid.x) + 0.5) / width;
    float roughness = (float(tid.y) + 0.5) / height;

    float3 V;
    V.x = sqrt(1.0 - NdotV * NdotV);
    V.y = 0.0;
    V.z = NdotV;

    float A = 0.0;
    float B = 0.0;

    float3 N = float3(0.0, 0.0, 1.0);

    uint SAMPLE_COUNT = 1024u;
    for (uint i = 0; i < SAMPLE_COUNT; i++) {
        float2 xi = hammersley(i, SAMPLE_COUNT);
        float3 H = importance_sample_ggx(xi, N, roughness);
        float3 L = normalize(2.0 * dot(V, H) * H - V);

        float NdotL = max(L.z, 0.0);
        float NdotH = max(H.z, 0.0);
        float VdotH = max(dot(V, H), 0.0);

        if (NdotL > 0.0) {
            float G = geometry_smith_ibl(N, V, L, roughness);
            float G_Vis = (G * VdotH) / max(NdotH * NdotV, 0.001);
            float Fc = pow(1.0 - VdotH, 5.0);

            A += (1.0 - Fc) * G_Vis;
            B += Fc * G_Vis;
        }
    }

    A /= float(SAMPLE_COUNT);
    B /= float(SAMPLE_COUNT);

    lut.write(float4(A, B, 0.0, 1.0), tid);
}
