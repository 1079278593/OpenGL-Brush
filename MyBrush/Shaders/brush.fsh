#version 300 es

#ifdef GL_ES
precision highp float;
#endif

uniform vec4 u_color;
uniform float u_alpha;
uniform sampler2D u_texture;

in vec2 v_texCoord;
out vec4 fragColor;

void main()
{
    fragColor = vec4(0.2f, 0.5f, 0.2f, u_alpha) * texture(u_texture, v_texCoord.st) ;
//    fragColor = vec4(0.2f, 0.5f, 0.2f, u_alpha);
}
