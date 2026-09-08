#version 300 es
precision highp float;
in vec2 frag_texcoord;
in vec4 frag_color;
out vec4 final_color;
uniform sampler2D tex;
uniform vec4 source_rect;
uniform vec4 borders;
uniform vec4 destination;
uniform vec2 atlas_size;
float slice_axis(float p, float size, float source_size, float lo, float hi, float scale) {
    float fit = min(scale, size / max(lo + hi, 0.0001));
    float a = lo * fit, b = hi * fit;
    if (p < a) return p / max(a, 0.0001) * lo;
    if (p > size - b) return source_size - (size - p) / max(b, 0.0001) * hi;
    return lo + (p - a) / max(size - a - b, 0.0001) * (source_size - lo - hi);
}
void main() {
    vec2 p = frag_texcoord * destination.xy;
    vec2 q = vec2(slice_axis(p.x, destination.x, source_rect.z, borders.x, borders.z, destination.z),
                  slice_axis(p.y, destination.y, source_rect.w, borders.y, borders.w, destination.z));
    q = clamp(q, vec2(0.5), source_rect.zw - vec2(0.5));
    final_color = texture(tex, (source_rect.xy + q) / atlas_size) * frag_color;
}
