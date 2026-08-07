#version 440

// wp_radial.frag — Radial (circular) wipe transition
// Copyright-free for your project

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 0) uniform sampler2D currentTex;
layout(binding = 1) uniform sampler2D nextTex;

layout(std140, binding = 0) uniform qt_buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float progress;
    float centerX;
    float centerY;
    float softness;
    float direction;     // 0.0 = outward, 1.0 = inward
};

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 current = texture(currentTex, uv);
    vec4 next    = texture(nextTex, uv);

    vec2 center = vec2(centerX, centerY);
    float dist = distance(uv, center);

    float radius = (direction < 0.5)
                 ? progress * 1.5          // outward
                 : (1.0 - progress) * 1.5; // inward

    // edge=0 where dist < radius (current shows), edge=1 where dist > radius (next shows)
    // 1.0 - smoothstep so progress=0 shows current everywhere
    float edge = 1.0 - smoothstep(radius - softness, radius + softness, dist);

    fragColor = mix(current, next, edge) * qt_Opacity;
}
