#include <metal_stdlib>
using namespace metal;

// CAUSA RAÍZ del visor negro (2026-07-08): este struct declaraba un 4º atributo
// `color [[attribute(3)]]` que el vertex descriptor del pipeline NO definía →
// makeRenderPipelineState fallaba → basicPipelineState = nil → CERO draws.
// El color del modelo ahora viaja en Uniforms.modelColor (es per-modelo, no
// per-vértice — el buffer real son 9 floats: pos4+normal3+uv2).
struct VertexIn {
    float4 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldNormal;
    float2 uv;
    float4 color;
    float3 worldPosition;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 ambientColor;
    float3 lightDirection;
    float3 lightColor;
    float lightIntensity;
    float3x3 normalMatrix;
    float4 modelColor;   // color per-modelo (debe espejar BasicUniforms en Swift)
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    float4 worldPos = uniforms.modelMatrix * float4(in.position.xyz, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.worldNormal = normalize(uniforms.normalMatrix * in.normal);
    out.uv = in.uv;
    out.color = uniforms.modelColor;
    out.worldPosition = worldPos.xyz;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    float3 N = normalize(in.worldNormal);
    float3 L = normalize(-uniforms.lightDirection);
    float diff = max(dot(N, L), 0.0);
    float3 lighting = uniforms.ambientColor + uniforms.lightColor * uniforms.lightIntensity * diff;
    float4 baseColor = in.color;
    return float4(baseColor.rgb * lighting, baseColor.a);
}

struct StrokeVertexIn {
    float4 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 size [[attribute(2)]];
};

struct StrokeVertexOut {
    float4 position [[position]];
    float4 color;
    float2 uv;
};

vertex StrokeVertexOut strokeVertex(StrokeVertexIn in [[stage_in]], constant float4x4 &mvp [[buffer(1)]], uint vid [[vertex_id]], uint iid [[instance_id]]) {
    StrokeVertexOut out;
    float2 offsets[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(1, -1), float2(1, 1), float2(-1, 1)
    };
    float2 uvs[6] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(1, 1), float2(1, 0), float2(0, 0)
    };
    float4 center = mvp * in.position;
    float2 offset = offsets[vid] * in.size * 0.5;
    out.position = center + float4(offset, 0, 0);
    out.color = in.color;
    out.uv = uvs[vid];
    return out;
}

fragment float4 strokeFragment(StrokeVertexOut in [[stage_in]]) {
    float dist = length(in.uv - 0.5) * 2.0;
    float alpha = 1.0 - smoothstep(0.0, 1.0, dist);
    return float4(in.color.rgb, in.color.a * alpha);
}
