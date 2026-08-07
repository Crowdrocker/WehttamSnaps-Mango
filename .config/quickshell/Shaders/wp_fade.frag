#version 440
//
// wp_fade.frag  —  wallpaper fade-out transition
// Written from scratch. No third-party code.
//
// Fades the current wallpaper out while the next one (rendered underneath
// by the QML stack) fades in, giving a smooth dissolve without any black frame.
//

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 0) uniform sampler2D currentTex;
layout(binding = 1) uniform sampler2D nextTex;

layout(std140, binding = 0) uniform qt_buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;       // 0.0 = current fully visible, 1.0 = next fully visible
};

void main() {
    vec4 src  = texture(currentTex, qt_TexCoord0);
    vec4 dst  = texture(nextTex,    qt_TexCoord0);

    // Smooth the progress curve (smoothstep gives a nicer feel than linear)
    float t = smoothstep(0.0, 1.0, progress);

    // Cross-dissolve: fade old out, new in
    fragColor = mix(src, dst, t) * qt_Opacity;
}
