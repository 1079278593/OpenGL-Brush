#ifdef GL_ES
precision highp float;
#endif

#if __VERSION__ >= 140
in vec2      varTexcoord;
in float     varIntensity;
out vec4     fragColor;
#else
varying vec2 varTexcoord;
varying float varIntensity;
#endif

uniform sampler2D texture;

void main (void)
{
    //texture2D()在OpenGL 3.3时被弃用。texture()
    float f = texture2D(texture, varTexcoord.st, 0.0).a;
    float v = varIntensity * f;
    
    gl_FragColor = vec4(0, 0, 0, v);
}
