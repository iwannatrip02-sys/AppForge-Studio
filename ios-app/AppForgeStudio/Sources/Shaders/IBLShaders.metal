#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldNormal;
    float2 uv;
    float3 worldPosition;
    float3 tangent;
};

struct FrameUniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4 cameraPosition;
    float3x3 normalMatrix;
};

struct PBRMaterialUniforms {
    float3 albedo;
    float metallic;
    float roughness;
    float ao;
    float3 emission;
    float emissionIntensity;
};

struct PointLight {
    float3 position;
    float3 color;
    float intensity;
    float range;
};

struct DirectionalLight {
    float3 direction;
    float3 color;
    float intensity;
};

struct LightUniforms {
    float3 ambientColor;
    uint pointLightCount;
    DirectionalLight directionalLight;
    PointLight pointLights[4];
};

struct IBLUniforms {
    float4x4 inverseView;
    float roughnessLevels;
};

float3 fresnel_schlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float distribution_ggx(float3 N, float3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = M_PI_F * denom * denom;

    return a2 / denom;
}

float geometry_schlick_ggx(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

float geometry_smith(float3 N, float3 V, float3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    return geometry_schlick_ggx(NdotV, roughness) * geometry_schlick_ggx(NdotL, roughness);
}

float3 calculate_pbr_directional(
    float3 worldPos,
    float3 N,
    float3 V,
    PBRMaterialUniforms material,
    DirectionalLight light
) {
    float3 L = normalize(-light.direction);
    float3 H = normalize(V + L);
    float3 radiance = light.color * light.intensity;

    float3 F0 = mix(float3(0.04), material.albedo, material.metallic);
    float3 F = fresnel_schlick(max(dot(H, V), 0.0), F0);

    float D = distribution_ggx(N, H, material.roughness);
    float G = geometry_smith(N, V, L, material.roughness);

    float3 numerator = D * G * F;
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float denominator = 4.0 * NdotV * NdotL + 0.0001;
    float3 specular = numerator / denominator;

    float3 kS = F;
    float3 kD = (1.0 - kS) * (1.0 - material.metallic);

    return (kD * material.albedo / M_PI_F + specular) * radiance * NdotL;
}

float3 calculate_pbr_point(
    float3 worldPos,
    float3 N,
    float3 V,
    PBRMaterialUniforms material,
    PointLight light
) {
    float3 L = light.position - worldPos;
    float distance = length(L);
    L = normalize(L);
    float3 H = normalize(V + L);

    float attenuation = light.range > 0.0 ?
        pow(max(1.0 - distance / light.range, 0.0), 2.0) / (distance * distance + 1.0) :
        1.0 / (distance * distance + 0.0001);
    float3 radiance = light.color * light.intensity * attenuation;

    float3 F0 = mix(float3(0.04), material.albedo, material.metallic);
    float3 F = fresnel_schlick(max(dot(H, V), 0.0), F0);

    float D = distribution_ggx(N, H, material.roughness);
    float G = geometry_smith(N, V, L, material.roughness);

    float3 numerator = D * G * F;
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float denominator = 4.0 * NdotV * NdotL + 0.0001;
    float3 specular = numerator / denominator;

    float3 kS = F;
    float3 kD = (1.0 - kS) * (1.0 - material.metallic);

    return (kD * material.albedo / M_PI_F + specular) * radiance * NdotL;
}

float3 ACES_tone_map(float3 color) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return (color * (a * color + b)) / (color * (c * color + d) + e);
}

float3 fresnel_schlick_roughness(float cosTheta, float3 F0, float roughness) {
    return F0 + (max(float3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

float3 specularIBL(float3 N, float3 V, float roughness, texturecube<float> prefilter, sampler s, float3 F0, float levels) {
    float3 R = reflect(-V, N);
    float3 prefilteredColor = prefilter.sample(s, R, level(roughness * levels)).rgb;
    return prefilteredColor;
}

float3 diffuseIBL(float3 N, texturecube<float> irradiance, sampler s) {
    return irradiance.sample(s, N).rgb;
}

vertex VertexOut ibl_vertex_main(
    VertexIn in [[stage_in]],
    constant FrameUniforms& uniforms [[buffer(1)]]
) {
    VertexOut out;
    float4 worldPos = uniforms.modelMatrix * float4(in.position.xyz, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.worldNormal = normalize(uniforms.normalMatrix * in.normal);
    out.uv = in.uv;
    out.worldPosition = worldPos.xyz;

    float3 up = abs(in.normal.y) < 0.999 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
    out.tangent = normalize(uniforms.normalMatrix * normalize(cross(up, in.normal)));

    return out;
}

fragment float4 ibl_fragment_main(
    VertexOut in [[stage_in]],
    constant FrameUniforms& frame [[buffer(1)]],
    constant PBRMaterialUniforms& material [[buffer(2)]],
    constant LightUniforms& lights [[buffer(3)]],
    constant IBLUniforms& ibl [[buffer(4)]],
    texturecube<float> irradianceMap [[texture(0)]],
    texturecube<float> prefilterMap [[texture(1)]],
    texture2d<float> brdfLUT [[texture(2)]],
    sampler textureSampler [[sampler(0)]]
) {
    float3 N = normalize(in.worldNormal);
    float3 V = normalize(frame.cameraPosition.xyz - in.worldPosition);

    float3 F0 = mix(float3(0.04), material.albedo, material.metallic);
    float3 kS = fresnel_schlick_roughness(max(dot(N, V), 0.0), F0, material.roughness);
    float3 kD = (1.0 - kS) * (1.0 - material.metallic);

    float3 irradiance = diffuseIBL(N, irradianceMap, textureSampler);
    float3 diffuse = irradiance * material.albedo;

    float3 prefilteredColor = specularIBL(N, V, material.roughness, prefilterMap, textureSampler, F0, ibl.roughnessLevels);
    float2 envBRDF = brdfLUT.sample(textureSampler, float2(max(dot(N, V), 0.0), material.roughness)).rg;
    float3 specular = prefilteredColor * (kS * envBRDF.x + envBRDF.y);

    float3 ambient = (kD * diffuse + specular) * material.ao;

    float3 Lo = float3(0.0);
    Lo += calculate_pbr_directional(in.worldPosition, N, V, material, lights.directionalLight);

    for (uint i = 0; i < lights.pointLightCount && i < 4; i++) {
        Lo += calculate_pbr_point(in.worldPosition, N, V, material, lights.pointLights[i]);
    }

    float3 color = ambient + Lo + material.emission * material.emissionIntensity;

    color = ACES_tone_map(color);
    color = pow(color, float3(1.0 / 2.2));

    return float4(color, 1.0);
}

// Face uv to direction vector for cubemap rendering
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

// Convert lat-long to UV for equirectangular sampling
float2 direction_to_uv(float3 dir) {
    float phi = atan2(dir.z, dir.x);
    float theta = acos(dir.y);
    return float2(phi / (2.0 * M_PI_F) + 0.5, theta / M_PI_F);
}

kernel void equirect_to_cubemap(
    texture2d<float, access::read> equirect [[texture(0)]],
    texturecube<float, access::write> cubemap [[texture(1)]],
    uint3 tid [[thread_position_in_grid]]
) {
    uint face = tid.x;
    float2 uv = (float2(tid.y, tid.z) + 0.5) / float2(cubemap.get_width(), cubemap.get_height());
    float3 dir = normalize(face_uv_to_direction(face, uv));
    float2 eqUV = direction_to_uv(dir);
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float3 color = equirect.sample(s, eqUV).rgb;
    cubemap.write(float4(color, 1.0), tid.yz, face);
}

kernel void irradiance_convolution(
    texturecube<float, access::read> envMap [[texture(0)]],
    texturecube<float, access::write> irradiance [[texture(1)]],
    uint3 tid [[thread_position_in_grid]]
) {
    uint face = tid.x;
    float2 uv = (float2(tid.y, tid.z) + 0.5) / float2(irradiance.get_width(), irradiance.get_height());
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
            color += envMap.sample(s, sampleVec).rgb * cos(theta) * sin(theta);
            nrSamples += 1.0;
        }
    }

    color = M_PI_F * color / nrSamples;
    irradiance.write(float4(color, 1.0), tid.yz, face);
}

// Van der Corput sequence for importance sampling
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

kernel void prefilter_convolution(
    texturecube<float, access::read> envMap [[texture(0)]],
    texturecube<float, access::write> prefilter [[texture(1)]],
    constant float& roughness [[buffer(0)]],
    uint3 tid [[thread_position_in_grid]]
) {
    uint face = tid.x;
    float2 uv = (float2(tid.y, tid.z) + 0.5) / float2(prefilter.get_width(tid.z), prefilter.get_height(tid.z));
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
            prefilteredColor += envMap.sample(s, L).rgb * NdotL;
            totalWeight += NdotL;
        }
    }

    prefilteredColor = prefilteredColor / max(totalWeight, 0.001);
    prefilter.write(float4(prefilteredColor, 1.0), tid.yz, face);
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

kernel void brdf_lut(
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
