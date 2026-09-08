cbuffer constants : register(b0) {
    float4x4 view_projection;
    float4 source_rect;
    float4 borders;
    float4 destination; // width, height, border scale, unused
    float2 atlas_size;
}
struct vs_in { float3 position : position; float2 texcoord : texcoord; float4 color : color; };
struct vs_out { float4 position : SV_POSITION; float2 texcoord : texcoord; float4 color : color; };
Texture2D tex : register(t0);
SamplerState smp : register(s0);
vs_out vs_main(vs_in input) {
    vs_out output;
    output.position = mul(view_projection, float4(input.position, 1));
    output.texcoord = input.texcoord;
    output.color = input.color;
    return output;
}
float slice_axis(float p, float size, float source_size, float lo, float hi, float scale) {
    float fit = min(scale, size / max(lo + hi, 0.0001));
    float a = lo * fit, b = hi * fit;
    if (p < a) return p / max(a, 0.0001) * lo;
    if (p > size - b) return source_size - (size - p) / max(b, 0.0001) * hi;
    return lo + (p - a) / max(size - a - b, 0.0001) * (source_size - lo - hi);
}
float4 ps_main(vs_out input) : SV_TARGET {
    float2 p = input.texcoord * destination.xy;
    float2 q = float2(slice_axis(p.x, destination.x, source_rect.z, borders.x, borders.z, destination.z),
                      slice_axis(p.y, destination.y, source_rect.w, borders.y, borders.w, destination.z));
    q = clamp(q, 0.5, source_rect.zw - 0.5);
    return tex.Sample(smp, (source_rect.xy + q) / atlas_size) * input.color;
}
