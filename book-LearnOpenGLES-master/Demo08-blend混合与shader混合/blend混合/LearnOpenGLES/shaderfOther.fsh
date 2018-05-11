varying lowp vec2 varyTextCoord;
varying lowp vec2 varyOtherPostion;

uniform sampler2D myTexture1;

void main()
{
    lowp vec4 text = texture2D(myTexture1, 1.0 - varyTextCoord);
    text.a = 0.8;
    gl_FragColor = text;
//    gl_FragColor = (1.0 - text.a) * gl_lastFragData[0] + text * text.a;
}
