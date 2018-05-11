//
//  ViewController.m
//  LearnOpenGLES
//
//  Created by loyinglin on 16/5/10.
//  Copyright © 2016年 loyinglin. All rights reserved.
//

attribute vec4 position;
attribute vec2 texCoord;

uniform float preferredRotation;
uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

varying lowp vec3 varyOtherPostion;
varying lowp vec2 texCoordVarying;

void main()
{
    mat4 rotationMatrix = mat4( cos(preferredRotation), -sin(preferredRotation), 0.0, 0.0,
                               sin(preferredRotation),  cos(preferredRotation), 0.0, 0.0,
                               0.0,					    0.0, 1.0, 0.0,
                               0.0,					    0.0, 0.0, 1.0);
    gl_Position = projectionMatrix * modelViewMatrix * rotationMatrix * position;// * modelViewMatrix * projectionMatrix;
    texCoordVarying = texCoord;
    varyOtherPostion = position.xyz;
}

