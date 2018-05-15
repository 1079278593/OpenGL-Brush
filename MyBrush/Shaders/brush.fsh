#version 300 es

#ifdef GL_ES
precision highp float;
#endif

uniform vec4 u_color;
uniform float u_pointSize;//未用到
uniform sampler2D u_texture;

in vec2 v_texCoord;
out vec4 fragColor;

void main()
{
    fragColor = texture(u_texture, v_texCoord) * u_color;
}
