#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
    float3 tangent [[attribute(3)]];
    float3 bitangent [[attribute(4)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldNormal;
    float2 uv;
    float3 worldPosition;
    float3 worldTangent;
    float3 worldBitangent;
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

// Fresnel-Schlick
float3 fresnel_schlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// GGX/Trowbridge-Reitz NDF
float distribution_ggx(float3 N, float3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = M_PI_F * denom * denom;

    return a2 / denom;
}

// Smith Schlick-GGX Geometry
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

vertex VertexOut pbr_vertex_main(
    VertexIn in [[stage_in]],
    constant FrameUniforms& uniforms [[buffer(1)]]
) {
    VertexOut out;
    float4 worldPos = uniforms.modelMatrix * float4(in.position.xyz, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.worldNormal = normalize(uniforms.normalMatrix * in.normal);
    out.worldTangent = normalize(uniforms.normalMatrix * in.tangent);
    out.worldBitangent = normalize(uniforms.normalMatrix * in.bitangent);
    out.uv = in.uv;
    out.worldPosition = worldPos.xyz;
    return out;
}

fragment float4 pbr_fragment_main(
    VertexOut in [[stage_in]],
    constant FrameUniforms& frame [[buffer(1)]],
    constant PBRMaterialUniforms& material [[buffer(2)]],
    constant LightUniforms& lights [[buffer(3)]],
    constant IBLUniforms& ibl [[buffer(4)]],
    texturecube<float> irradianceMap [[texture(6)]],
    texturecube<float> prefilterMap [[texture(7)]],
    texture2d<float> brdfLUT [[texture(8)]],
    sampler iblSampler [[sampler(1)]]
) {
    float3 N = normalize(in.worldNormal);

    float3 V = normalize(frame.cameraPosition.xyz - in.worldPosition);

    float3 Lo = float3(0.0);

    Lo += calculate_pbr_directional(in.worldPosition, N, V, material, lights.directionalLight);

    for (uint i = 0; i < lights.pointLightCount && i < 4; i++) {
        Lo += calculate_pbr_point(in.worldPosition, N, V, material, lights.pointLights[i]);
    }

    float3 ambient = lights.ambientColor * material.albedo * material.ao;

    float3 color = ambient + Lo + material.emission * material.emissionIntensity;

    float3 F0 = mix(float3(0.04), material.albedo, material.metallic);
    float3 specIBL = specularIBL(N, V, material.roughness, prefilterMap, iblSampler, F0, ibl.roughnessLevels);
    float2 brdf = brdfIBL(max(dot(N, V), 0.0), material.roughness, brdfLUT, iblSampler);
    float3 iblContrib = diffuseIBL(N, irradianceMap, iblSampler) * (1.0 - material.metallic) * (float3(1.0) - specIBL) + specIBL + float3(brdf, 0.0);
    color += iblContrib;

    color = ACES_tone_map(color);

    color = pow(color, float3(1.0 / 2.2));

    return float4(color, 1.0);
}

fragment float4 pbr_ibl_fragment_main(
    VertexOut in [[stage_in]],
    constant FrameUniforms& frame [[buffer(1)]],
    constant PBRMaterialUniforms& material [[buffer(2)]],
    constant LightUniforms& lights [[buffer(3)]],
    constant IBLUniforms& ibl [[buffer(4)]],
    texturecube<float> irradianceMap [[texture(0)]],
    texturecube<float> prefilterMap [[texture(1)]],
    texture2d<float> brdfLUT [[texture(2)]],
    texture2d<float> normalMap [[texture(4)]],
    sampler textureSampler [[sampler(0)]]
) {
    float3 N;
    if (length(in.worldTangent) > 0.001) {
        float3 T = normalize(in.worldTangent);
        float3 Ng = normalize(in.worldNormal);
        T = normalize(T - Ng * dot(Ng, T));
        float3 B = normalize(cross(Ng, T));
        float3x3 TBN = float3x3(T, B, Ng);
        float3 tangentNormal = normalMap.sample(textureSampler, in.uv).rgb * 2.0 - 1.0;
        N = normalize(TBN * tangentNormal);
    } else {
        N = normalize(in.worldNormal);
    }
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

float2 brdfIBL(float NdotV, float roughness, texture2d<float> brdfLUT, sampler s) {
    return brdfLUT.sample(s, float2(NdotV, roughness)).rg;
}
