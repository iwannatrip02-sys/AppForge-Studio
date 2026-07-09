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
    float4 cameraPos;    // posición de cámara (specular/rim del shading moderno)
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

// Shading "estudio" (acabado Shapr3D/Nomad, adiós al lambert plano de los 90):
// half-Lambert (sin negros duros) + ambiente HEMISFÉRICO (cielo frío arriba,
// suelo oscuro abajo) + especular Blinn suave + rim frío sutil.
fragment float4 fragment_main(VertexOut in [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    float3 N = normalize(in.worldNormal);
    float3 L = normalize(-uniforms.lightDirection);
    float3 V = normalize(uniforms.cameraPos.xyz - in.worldPosition);

    float ndl = dot(N, L) * 0.5 + 0.5;
    float diff = ndl * ndl;

    float hemi = N.y * 0.5 + 0.5;
    float3 ambient = mix(float3(0.15, 0.145, 0.16), float3(0.33, 0.36, 0.42), hemi);

    float3 H = normalize(L + V);
    float spec = pow(max(dot(N, H), 0.0), 48.0) * 0.30;
    float rim = pow(1.0 - max(dot(N, V), 0.0), 3.0) * 0.18;

    float4 baseColor = in.color;
    float3 lighting = ambient + uniforms.lightColor * uniforms.lightIntensity * diff;
    float3 rgb = baseColor.rgb * lighting + float3(spec) + float3(0.55, 0.65, 0.80) * rim;
    return float4(rgb, baseColor.a);
}

// MARK: - Fondo con gradiente (el negro plano gritaba prototipo)

struct BGVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex BGVertexOut bg_vertex(uint vid [[vertex_id]]) {
    // Triángulo fullscreen
    float2 p[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };
    BGVertexOut out;
    out.position = float4(p[vid], 0.999, 1.0);
    out.uv = p[vid] * 0.5 + 0.5;
    return out;
}

fragment float4 bg_fragment(BGVertexOut in [[stage_in]]) {
    // Taller de noche: sutil luz cenital fría que cae a grafito profundo,
    // con viñeta suave en las esquinas.
    float3 top = float3(0.085, 0.095, 0.125);
    float3 bottom = float3(0.035, 0.038, 0.052);
    float3 c = mix(bottom, top, in.uv.y);
    float2 d = in.uv - float2(0.5, 0.55);
    c *= 1.0 - dot(d, d) * 0.55;   // viñeta
    return float4(c, 1.0);
}

// MARK: - Grilla universal del piso (procedural, antialiased)
// Quad gigante en y=0; el fragment dibuja líneas cada 0.5 (menores) y 2.5
// (mayores) con fade por distancia. Acero frío sutil (IDENTIDAD_FORGE §5:
// la grilla jamás compite con la geometría).

struct GridVertexOut {
    float4 position [[position]];
    float3 worldPos;
};

vertex GridVertexOut grid_vertex(uint vid [[vertex_id]],
                                 constant Uniforms &uniforms [[buffer(1)]]) {
    float2 corners[6] = {
        float2(-1,-1), float2(1,-1), float2(1,1),
        float2(-1,-1), float2(1,1), float2(-1,1)
    };
    float s = 60.0;
    float3 world = float3(corners[vid].x * s, 0.0, corners[vid].y * s);
    GridVertexOut out;
    out.worldPos = world;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * float4(world, 1.0);
    return out;
}

fragment float4 grid_fragment(GridVertexOut in [[stage_in]]) {
    float2 p = in.worldPos.xz;
    float2 gMinor = abs(fract(p / 0.5 - 0.5) - 0.5) / fwidth(p / 0.5);
    float lineMinor = 1.0 - min(min(gMinor.x, gMinor.y), 1.0);
    float2 gMajor = abs(fract(p / 2.5 - 0.5) - 0.5) / fwidth(p / 2.5);
    float lineMajor = 1.0 - min(min(gMajor.x, gMajor.y), 1.0);
    float fade = saturate(1.0 - length(p) / 28.0);

    // Ejes del mundo (convención universal, como Shapr3D): X rojo, Z azul.
    float axX = 1.0 - min(abs(p.y) / fwidth(p.y) / 1.6, 1.0);   // línea z=0 → eje X
    float axZ = 1.0 - min(abs(p.x) / fwidth(p.x) / 1.6, 1.0);   // línea x=0 → eje Z

    float a = max(lineMinor * 0.16, lineMajor * 0.32) * fade;
    float3 color = float3(0.44, 0.64, 0.82);   // steel #6FA3D0
    if (axX > 0.0) { color = float3(0.97, 0.44, 0.44); a = max(a, axX * 0.55 * fade); }  // axisX #F87171
    if (axZ > 0.0) { color = float3(0.30, 0.64, 1.00); a = max(a, axZ * 0.55 * fade); }  // axisZ #4DA3FF
    if (a < 0.01) { discard_fragment(); }
    return float4(color, a);
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
