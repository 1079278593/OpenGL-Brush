#extension GL_EXT_shader_framebuffer_fetch : require

//#ifdef GL_ES
//varying lowp vec4 v_fragmentColor;
//varying lowp vec4 v_position;
//#else
//varying vec4 v_fragmentColor;
//#endif

varying lowp vec2 varyTextCoord;
varying lowp vec2 varyOtherPostion;

uniform sampler2D myTexture1;

void main()
{
    lowp vec4 text = texture2D(myTexture1, 1.0 - varyTextCoord);
    text.a = 0.8;
    lowp vec4 test = gl_LastFragData[0];
    gl_FragColor = (1.0 - text.a) * test + text * text.a;

}
