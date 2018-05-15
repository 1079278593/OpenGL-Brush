#ifdef GL_ES
precision highp float;
#endif

/**
 Screen 滤色
 C=255-(A反相×B反相)/255
 
 该模式和上一个模式刚好相反，
 上下层像素的标准色彩值反相后相乘后输出，
 输出结果比两者的像素值都将要亮
 （就好像两台投影机分别对其中一个图层进行投影后，然后投射到同一个屏幕上）。
 从右边公式中我们可以看出，如果两个图层反相后，采用Multiply模式混合，
 则将和对这两个图层采用 Screen模式混合后反相的结果完全一样。
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
    vec4 result = white - ((white - blendColor) * (white - baseColor));
    
    gl_FragColor = mix(baseColor, result, opacity);
}
