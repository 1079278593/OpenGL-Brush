#ifdef GL_ES
precision highp float;
#endif

/**
 Color Burn 颜色加深
 C=A-(A反相×B反相)/B
 
 该模式和上一个模式刚好相反。
 如果上层越暗，则下层获取的光越少，
 如果上层为全黑色，则下层越黑，
 如果上层为全白色，则根本不会影响下层。
 结果最亮的地方不会高于下层的像素值。
 */

// uniforms
uniform sampler2D   baseImage;
uniform sampler2D   blendImage;
uniform float       opacity;
uniform bool        bottom;

varying vec2 varTexcoord;

const vec4 white = vec4(1.0, 1.0, 1.0, 1.0);

void main (void)
{
    vec4 baseColor = bottom ? white : texture2D(baseImage, varTexcoord.st);
    vec4 blendColor = texture2D(blendImage, varTexcoord.st);
    
    // perform color burn blend
    vec4 result = white - (white - baseColor) / blendColor;
    
    gl_FragColor = mix(baseColor, result, opacity);
}
