precision highp float;
in vec2 frag_uv;
in vec4 frag_color;
out vec4 final_color;
uniform sampler2D tex;
uniform vec4 source_rect;
uniform vec4 source_borders;
uniform vec4 dest_size_scale;
uniform vec2 atlas_size;
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
void main() {
    vec2 dest_pos = frag_uv * dest_size_scale.xy;
    vec2 source_pos = vec2(
        map_slice_axis(
            dest_pos.x, dest_size_scale.x, source_rect.z,
            source_borders.x, source_borders.z, dest_size_scale.z
        ),
        map_slice_axis(
            dest_pos.y, dest_size_scale.y, source_rect.w,
            source_borders.y, source_borders.w, dest_size_scale.z
        )
    );
    source_pos = clamp(source_pos, vec2(0.5), source_rect.zw - vec2(0.5));
    final_color = texture(tex, (source_rect.xy + source_pos) / atlas_size) * frag_color;
}
