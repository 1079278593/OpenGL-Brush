attribute vec4 position;
attribute vec2 textCoordinate;

varying lowp vec2 varyTextCoord;
varying lowp vec2 varyOtherPostion;

void main()
{
    varyTextCoord = textCoordinate;
    varyOtherPostion = position.xy;
    
    gl_Position = position;
}
