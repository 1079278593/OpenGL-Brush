#ifdef GL_ES
precision highp float;
#endif

/**
 Darken 变暗
 B<=A 则 C=B B>=A 则 C=A
 
 该模式通过比较上下层像素后取相对较暗的像素作为输出，
 注意，每个不同的颜色通道的像素都是独立的进行比较，色彩值相对较小的作为输出结果。
 下层表示叠放次序位于下面的那个图层，
 上层表示叠放次序位于上面的那个图层
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
    
    // perform darken blend
    vec4 result = min(blendColor, baseColor);
    
    gl_FragColor = mix(baseColor, result, opacity);
}
