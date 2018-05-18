#version 300 es

uniform mat4 u_mvpMatrix;
uniform float u_scale;

//这里的in类型的变量，按照前后顺序传入ShaderModel，location从0开始递增。
//通用顶点使用ShaderModel的函数locationForUniform()获取location
in vec3 a_position;
in vec2 a_texCoord;
out vec2 v_texCoord;

void main()
{

    gl_Position = u_mvpMatrix * vec4(a_position, 1.0);
    
    v_texCoord = a_texCoord;
}
