#version 300 es

uniform mat4 u_mvpMatrix;
uniform float u_scale;

//这里的in类型的变量，按照前后顺序传入ShaderModel，location从0开始递增。
//通用顶点使用ShaderModel的函数locationForUniform()获取location
in vec3 a_position;
in vec2 a_texCoord;
in float a_angle;//随机角度
out mat4 v_rotationMatrix;
out vec2 v_texCoord;
out float v_angle;

const float zero = 0.0;
const float one = 1.0;

void main()
{

    gl_Position = u_mvpMatrix * vec4(a_position, one);
    
    v_texCoord = a_texCoord;
    
    v_angle = a_angle;
    //随机角度
    float sinAngle = sin(a_angle);
    float cosAngle = cos(a_angle);
    v_rotationMatrix = mat4(  cosAngle, sinAngle,  zero,  zero,
                             -sinAngle, cosAngle,  zero,  zero,
                                zero,   zero,      one,   zero,
                                zero,   zero,      zero,  one);
     
    
//    gl_Position = v_rotationMatrix * gl_Position;
}
