#version 440
// Cloth-flag entrance for the control centre: the panel hangs from the bar, drops with bunched
// folds that pull flat, then a damped ripple runs down it. p = open progress, t = ripple clock (s).
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 v_uv;
layout(location = 1) out float v_shade;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float p;
    float t;
    float amp;
    vec2 dim;
};
void main() {
    vec2 uv = qt_MultiTexCoord0;
    float W = dim.x, H = dim.y, comp = 1.0 - p, decay = exp(-t * 2.6);
    float fold = sin(uv.y * 42.0 + uv.x * 1.6) * comp;
    float rip = sin(uv.y * 9.0 - t * 11.0 + uv.x * 2.4) * decay * uv.y;
    float z = (fold * 16.0 + rip * 14.0) * amp;
    float y = uv.y * H * p - sin(uv.x * 3.14159) * uv.y * comp * 18.0 * amp;
    float x = uv.x * W + sin(t * 6.5 + uv.y * 3.0) * decay * uv.y * 9.0 * amp;
    x = (x - W * 0.5) * (1.0 + z * 0.0016) + W * 0.5;
    float dz = cos(uv.y * 42.0 + uv.x * 1.6) * comp * 0.55 + cos(uv.y * 9.0 - t * 11.0 + uv.x * 2.4) * decay * uv.y * 0.45;
    v_uv = uv;
    v_shade = 1.0 + dz * amp * 0.6;
    gl_Position = qt_Matrix * vec4(x, max(y, 0.0), 0.0, 1.0);
}
