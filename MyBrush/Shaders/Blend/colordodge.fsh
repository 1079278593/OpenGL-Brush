#ifdef GL_ES
precision highp float;
#endif

/**
 Color Dodge 颜色减淡
 C=A+(A×B)/B反相
 
 该模式下，上层的亮度决定了下层的暴露程度。
 如果上层越亮，下层获取的光越多，也就是越亮。
 如果上层是纯黑色，也就是没有亮度，则根本不会影响下层。
 如果上层是纯白色，则下层除了像素为255的地方暴露外，
 其他地方全部为白色（也就是255，不暴露）。
 结果最黑的地方不会低于下层的像素值。
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
    
    // perform color dodge blend
    vec4 result = baseColor / (white - blendColor);
    
    gl_FragColor = mix(baseColor, result, opacity);
}
