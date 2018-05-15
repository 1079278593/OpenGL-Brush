#ifdef GL_ES
precision highp float;
#endif

/**
 Difference 差值
 C=|A-B|
 
 上下层色调的绝对值。
 该模式主要用于比较两个不同版本的图片。
 如果两者完全一样，则结果为全黑。
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
    
    // perform difference blend
    vec4 result = abs(blendColor - baseColor);
    
    gl_FragColor = mix(baseColor, result, opacity);
}
