#ifdef GL_ES
precision highp float;
#endif

/**
 Overlay叠加
 A<=128 则 C=(A×B)/255 A>128 则 C=255-(A反相×B反相)/128
 
 依据下层色彩值的不同，该模式可能是Multiply （正片叠底），也可能是Screen （滤色）模式。
 上层决定了下层中间色调偏移的强度。
 如果上层为50%灰，则结果将完全为下层像素的值。
 如果上层比50%灰暗，则下层的中间色调的将向暗地方偏移，
 如果上层比50%灰亮，则下层的中间色调的将向亮地方偏移。
 对于上层比50%灰暗，下层中间色调以下的色带变窄（原来为0~2×0.4×0.5，现在为0~2×0.3×0.5），
 中间色调以上的色带变宽（原来为2×0.4×0.5~1，现在为2×0.3×0.5~1）。
 反之亦然。
 */

// uniforms
uniform sampler2D   baseImage;
uniform sampler2D   blendImage;
uniform float       opacity;
uniform bool        bottom;

varying vec2 varTexcoord;

const vec4 white = vec4(1.0, 1.0, 1.0, 1.0);
const vec4 lumCoeff = vec4(0.2125, 0.7154, 0.0721, 1.0);

void main (void)
{
    vec4    baseColor = bottom ? white : texture2D(baseImage, varTexcoord.st);
    vec4    blendColor = texture2D(blendImage, varTexcoord.st);
    float   luminance = dot(baseColor, lumCoeff);
    vec4    result;
    
    // perform overlay blend
    
    if (luminance < 0.45) {
        result = 2.0 * blendColor * baseColor;
    } else if (luminance > 0.55) {
        result = white - 2.0 * (white - blendColor) * (white - baseColor);
    } else {
        vec4 result1 = 2.0 * blendColor * baseColor;
        vec4 result2 = white - 2.0 * (white - blendColor) * (white - baseColor);
        result = mix(result1, result2, (luminance - 0.45) * 10.0);
    }
    
    gl_FragColor = mix(baseColor, result, opacity);
}
