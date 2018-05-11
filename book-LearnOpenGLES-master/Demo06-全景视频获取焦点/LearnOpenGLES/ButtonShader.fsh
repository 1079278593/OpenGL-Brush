//
//  ViewController.m
//  LearnOpenGLES
//
//  Created by loyinglin on 16/5/10.
//  Copyright © 2016年 loyinglin. All rights reserved.
//

varying lowp vec2 texCoordVarying;
varying lowp vec3 varyOtherPostion;
precision mediump float;

uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;
uniform mat3 colorConversionMatrix;
uniform vec2 leftBottom;
uniform vec2 rightTop;
uniform sampler2D myTexture1;

void main()
{
    mediump vec3 yuv;
    lowp vec3 rgb;
    
    // Subtract constants to map the video range start at 0
    yuv.x = (texture2D(SamplerY, texCoordVarying).r);// - (16.0/255.0));
    yuv.yz = (texture2D(SamplerUV, texCoordVarying).ra - vec2(0.5, 0.5));
    
    rgb = colorConversionMatrix * yuv;
    
    if (varyOtherPostion.x >= leftBottom.x && varyOtherPostion.y >= leftBottom.y && varyOtherPostion.x <= rightTop.x && varyOtherPostion.y <= rightTop.y && varyOtherPostion.z > 0.0) {
        lowp vec2 test = vec2((varyOtherPostion.x - leftBottom.x) / (rightTop.x - leftBottom.x), 1.0 -  (varyOtherPostion.y - leftBottom.y) / (rightTop.y - leftBottom.y));
        lowp vec4 otherColor = texture2D(myTexture1, test);
        otherColor.a = 0.5;
        gl_FragColor = otherColor * otherColor.a + vec4(rgb, 1.0) * (1.0 - otherColor.a);
    }
    else {
        gl_FragColor = vec4(rgb, 1.0);
    }
}