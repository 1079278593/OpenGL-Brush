#version 300 es

#ifdef GL_ES
precision highp float;
#endif

uniform vec4 u_color;
uniform float u_alpha;
uniform sampler2D u_texture;
uniform sampler2D u_mask;

in mat4 v_rotationMatrix;
in vec2 v_texCoord;
in float v_angle;
out vec4 fragColor;

void main()
{
    
    //随机角度
//    vec4 color = texture(u_texture, (v_rotationMatrix * vec4(v_texCoord.st - vec2(0.5), 0.0, 1.0)).xy + vec2(0.5)) ;
//    fragColor = texture(u_texture, v_texCoord.st * v_angle);
    
    
    //1.不旋转
    //1.1无mask
//    fragColor = texture(u_texture, v_texCoord.st)* vec4(1.0f, 1.0f, 1.0f, u_alpha);
    //1.2增加mask
//    vec4 src = texture(u_texture, v_texCoord.st)* vec4(1.0f, 1.0f, 1.0f, u_alpha);
//    float maskAlpha = texture(u_mask, v_texCoord.st).a;
//    fragColor = src * maskAlpha;

    
    //2.旋转
    //2.1无mask
//    fragColor = texture(u_texture, (v_rotationMatrix * vec4(v_texCoord.st - vec2(0.5), 0.0, 1.0)).xy + vec2(0.5));
    //2.2增加mask
    vec4 src = texture(u_texture, (v_rotationMatrix * vec4(v_texCoord.st - vec2(0.5), 0.0, 1.0)).xy + vec2(0.5)) * vec4(1.0f, 1.0f, 1.0f, u_alpha);
    float maskAlpha = texture(u_mask, v_texCoord.st).a;
    fragColor = src * maskAlpha;
}
