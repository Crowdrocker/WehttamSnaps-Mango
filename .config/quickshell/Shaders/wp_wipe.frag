#version 440

// ================================================
// wp_wipe.frag — Directional Wipe Transition
// Clean, performant, and copyright-free
// ================================================

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 0) uniform sampler2D currentTex;
layout(binding = 1) uniform sampler2D nextTex;

layout(std140, binding = 0) uniform qt_buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;      // 0.0 → 1.0
    float direction;     // 0.0 = Left→Right, 1.0 = Right→Left,
                         // 2.0 = Top→Bottom, 3.0 = Bottom→Top
    float softness;      // Edge softness (0.0 = sharp, 0.1 = soft)
};

void main() {
    vec4 current = texture(currentTex, qt_TexCoord0);
    vec4 next    = texture(nextTex,    qt_TexCoord0);

    float t = 0.0;

    // Choose wipe direction
    if (direction < 0.5) {
        // Left → Right
        t = qt_TexCoord0.x;
    } else if (direction < 1.5) {
        // Right → Left
        t = 1.0 - qt_TexCoord0.x;
    } else if (direction < 2.5) {
        // Top → Bottom
        t = qt_TexCoord0.y;
    } else {
        // Bottom → Top
        t = 1.0 - qt_TexCoord0.y;
    }

    // Soft edge — 1.0 - smoothstep so progress=0 shows current everywhere
    float edge = 1.0 - smoothstep(progress - softness, progress + softness, t);

    // Final blend
    vec4 blended = mix(current, next, edge);

    fragColor = blended * qt_Opacity;
}
