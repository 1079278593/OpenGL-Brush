varying lowp vec2 varyTextCoord;

uniform sampler2D myTexture0;

void main()
{
    gl_FragColor = texture2D(myTexture0, 1.0 - varyTextCoord);
}
