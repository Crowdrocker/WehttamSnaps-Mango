#version 440

// ================================================
// wp_crossfade.frag - Smooth Crossfade for Quickshell
// Copyright-free, written from scratch for your wallpaper system
// ================================================

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 0) uniform sampler2D currentTex;
layout(binding = 1) uniform sampler2D nextTex;

layout(std140, binding = 0) uniform qt_buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;        // 0.0 = current, 1.0 = next
};

void main() {
    vec4 current = texture(currentTex, qt_TexCoord0);
    vec4 next    = texture(nextTex,    qt_TexCoord0);

    // Smooth cubic ease (S-curve) - feels more natural than linear
    float t = progress * progress * (3.0 - 2.0 * progress);

    // Proper alpha-aware blending (premultiplied)
    vec4 currPremul = vec4(current.rgb * current.a, current.a);
    vec4 nextPremul = vec4(next.rgb    * next.a,    next.a);

    vec4 blended = mix(currPremul, nextPremul, t);

    // Convert back to straight alpha
    float alpha = blended.a;
    vec3 rgb = (alpha > 0.0001) ? blended.rgb / alpha : vec3(0.0);

    fragColor = vec4(rgb, alpha) * qt_Opacity;
}
