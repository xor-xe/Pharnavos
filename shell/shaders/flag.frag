#version 440
layout(location = 0) in vec2 v_uv;
layout(location = 1) in float v_shade;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float p;
    float t;
    float amp;
    vec2 dim;
};
layout(binding = 1) uniform sampler2D source;
void main() {
    vec4 c = texture(source, v_uv);   // premultiplied
    fragColor = vec4(min(c.rgb * v_shade, vec3(c.a)), c.a) * qt_Opacity;
}
