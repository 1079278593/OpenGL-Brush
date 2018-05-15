#ifdef GL_ES
precision highp float;
#endif

/**Exclusion 排除
 C=A+B-(A×B)/128
 
 亮的图片区域将导致另一层的反相，很暗的区域则将导致另一层完全没有改变。
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
    
    // perform exclusion blend
    vec4 result = baseColor + blendColor - (2.0 * baseColor * blendColor);
    
    gl_FragColor = mix(baseColor, result, opacity);
}
