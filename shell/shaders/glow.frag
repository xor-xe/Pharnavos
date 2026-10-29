#version 440
// The wallpaper's dim red glow: a soft falloff with no edge (a linear gradient ends in a visible ring)
// and a little noise, so dark red doesn't break into 8-bit bands.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // item size, px
    float radius;    // px: the glow is gone well before this
};

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 px = qt_TexCoord0 * res;
    float d = length(px - res * 0.5) / radius;
    float a = 0.28 * exp(-3.0 * d * d);                     // gaussian: reaches ~0 smoothly
    vec3 c = vec3(120.0, 10.0, 20.0) / 255.0 * a;           // premultiplied over black
    c += (hash(px) + hash(px + 17.0) - 1.0) / 255.0;        // triangular dither, ±1 step
    fragColor = vec4(max(c, 0.0), a) * qt_Opacity;
}
