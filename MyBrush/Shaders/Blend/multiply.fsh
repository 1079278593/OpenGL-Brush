#ifdef GL_ES
precision highp float;
#endif

/**
 Multiply 正片叠底
 C=(A×B)/255
 
 该效果将两层像素的标准色彩值（基于0..1之间）相乘后输出
 其效果可以形容成：两个幻灯片叠加在一起然后放映，
 透射光需要分别通过这两个幻灯片，从而被削弱了两次。
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
    
    // perform multiply blend
    vec4 result = blendColor * baseColor;
    
    gl_FragColor = mix(baseColor, result, opacity);
}
