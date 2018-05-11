uniform sampler2D texture;
varying lowp vec4 color;

void main()
{

    gl_FragColor = 0.9 * color * texture2D(texture, gl_PointCoord);
    
}
