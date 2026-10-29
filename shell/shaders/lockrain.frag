#version 440
// Letter rain for the lock screen: a grid of Georgian glyphs that flip at random, shown only where
// the mask is dark (St. George silhouette / five-cross flag), lit by a slow diagonal wave.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // item size, px
    vec2 origin;     // grid origin, px
    float cell;      // cell size, px
    float t;         // seconds
    float rate;      // glyph flips per second (rises while typing)
    float heat;      // 0..1, typing intensity
    float glyphs;    // glyph count in the atlas
    float mood;      // 0 idle, 1 wrong (red), 2 accepted (warm)
    vec4 maskRect;   // where the mask texture sits, in item uv (x, y, w, h)
};
layout(binding = 1) uniform sampler2D atlas;
layout(binding = 2) uniform sampler2D mask;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 p = qt_TexCoord0 * res;
    vec2 g = floor((p - origin) / cell);
    vec2 local = fract((p - origin) / cell);
    vec2 cuv = ((g + 0.5) * cell + origin) / res;
    vec2 muv = (cuv - maskRect.xy) / maskRect.zw;
    if (any(lessThan(muv, vec2(0.0))) || any(greaterThan(muv, vec2(1.0))) || texture(mask, muv).r > 0.47) {
        fragColor = vec4(0.0);
        return;
    }
    float h = hash(g);
    float step = floor(t * rate * (0.6 + 0.8 * h) + h * 37.0);
    float k = floor(hash(g + step * 0.731) * glyphs);
    vec2 l = clamp(local, 0.03, 0.97);   // stay inside this glyph's slot
    float ga = texture(atlas, vec2((k + l.x) / glyphs, l.y)).a;
    float wave = 0.55 + 0.45 * sin((p.x + p.y) / (140.0 * cell / 13.0) - t * 3.6);
    float a = min(1.0, (0.55 + 0.45 * wave) * (0.95 + heat * 0.3)) * ga;   // brighter base: smaller letters carry less ink
    vec3 c = mood > 1.5 ? vec3(1.0, 0.78, 0.47) : mood > 0.5 ? vec3(1.0, 0.165, 0.227) : vec3(1.0, (40.0 + wave * 40.0) / 255.0, 0.227);
    fragColor = vec4(c * a, a) * qt_Opacity;
}
