cbuffer constants : register(b0) {
    float4x4 view_projection;
    float4 source_rect;
    float4 source_borders;
    float4 dest_size_scale; // width, height, border scale, unused
    float2 atlas_size;
}
struct Vertex_Input {
    float3 position : position;
    float2 texcoord : texcoord;
    float4 color : color;
};
struct Vertex_Output {
    float4 position : SV_POSITION;
    float2 texcoord : texcoord;
    float4 color : color;
};
Texture2D tex : register(t0);
SamplerState atlas_sampler : register(s0);
Vertex_Output vs_main(Vertex_Input input) {
    Vertex_Output output;
    output.position = mul(view_projection, float4(input.position, 1));
    output.texcoord = input.texcoord;
    output.color = input.color;
    return output;
}
float map_slice_axis(
    float dest_pos,
    float dest_size,
    float source_size,
    float source_start,
    float source_end,
    float border_scale
) {
    if (source_start + source_end == 0.0) return dest_pos * source_size / dest_size;
    float fit_scale = min(border_scale, dest_size / (source_start + source_end));
    float dest_start = source_start * fit_scale;
    float dest_end = source_end * fit_scale;
    if (dest_pos < dest_start) return dest_pos / dest_start * source_start;
    if (dest_pos > dest_size - dest_end) return source_size - (dest_size - dest_pos) / dest_end * source_end;
    float dest_middle = dest_size - dest_start - dest_end;
    if (dest_middle <= 0.0) return source_start;
    return source_start + (dest_pos - dest_start) / dest_middle * (source_size - source_start - source_end);
}
float4 ps_main(Vertex_Output input) : SV_TARGET {
    float2 dest_pos = input.texcoord * dest_size_scale.xy;
    float2 source_pos = float2(
        map_slice_axis(
            dest_pos.x, dest_size_scale.x, source_rect.z,
            source_borders.x, source_borders.z, dest_size_scale.z
        ),
        map_slice_axis(
            dest_pos.y, dest_size_scale.y, source_rect.w,
            source_borders.y, source_borders.w, dest_size_scale.z
        )
    );
    source_pos = clamp(source_pos, 0.5, source_rect.zw - 0.5);
    return tex.Sample(atlas_sampler, (source_rect.xy + source_pos) / atlas_size) * input.color;
}
