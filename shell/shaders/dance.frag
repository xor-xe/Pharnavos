#version 440
// Dance wallpaper: Georgian letters, flipping at random, drawn on the cells where the current frame
// of a dancer's line art has a line. The frames are tiles of one sheet (white = line).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // item size, px
    vec2 origin;     // top-left of the dancer's grid, px
    vec2 cell;       // cell size, px
    vec2 grid;       // cells per frame (cols, rows)
    vec2 tiles;      // frames per sheet row, sheet rows
    float frame;     // current frame
    float t;         // seconds
    float glyphs;    // glyph count in the atlas
    float fade;      // 0..1: dips at the loop's seam
};
layout(binding = 1) uniform sampler2D atlas;
layout(binding = 2) uniform sampler2D sheet;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 p = qt_TexCoord0 * res;
    vec2 g = floor((p - origin) / cell);
    if (any(lessThan(g, vec2(0.0))) || any(greaterThanEqual(g, grid))) { fragColor = vec4(0.0); return; }
    vec2 tile = vec2(mod(frame, tiles.x), floor(frame / tiles.x));
    if (texture(sheet, (tile * grid + g + 0.5) / (tiles * grid)).r < 0.5) { fragColor = vec4(0.0); return; }
    float h = hash(g);
    float k = floor(hash(g + floor(t * 1.6 * (0.6 + 0.8 * h) + h * 37.0) * 0.731) * glyphs);
    vec2 l = clamp(fract((p - origin) / cell), 0.03, 0.97);
    float a = texture(atlas, vec2((k + l.x) / glyphs, l.y)).a * fade;
    fragColor = vec4(vec3(1.0, 0.157, 0.196) * a, a) * qt_Opacity;
}
