#ifdef GL_ES
precision highp float;
#endif

//straight blit 连续的位块传输。straight：直的、连续的

#if __VERSION__ >= 140
in vec2      varTexcoord;
out vec4     fragColor;
#else
varying vec2 varTexcoord;
#endif

uniform sampler2D texture;

void main (void)
{
    gl_FragColor = texture2D(texture, varTexcoord.st, 0.0);
}
