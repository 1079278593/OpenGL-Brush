//
//  ShaderModel.m
//  MyBrush
//
//  Created by 小明 on 2018/5/15.
//  Copyright © 2018年 laihua. All rights reserved.
//

#import "ShaderModel.h"

@interface ShaderModel ()

@end

@implementation ShaderModel

+ (ShaderModel *) shaderWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader
                      attributesNames:(NSArray *)attributeNames uniformNames:(NSArray *)uniformNames
{
    ShaderModel *shader = [[ShaderModel alloc] initWithVertexShader:vertexShader
                                               fragmentShader:fragmentShader
                                              attributesNames:attributeNames
                                                 uniformNames:uniformNames];
    
    return shader;
}

- (id) initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader
            attributesNames:(NSArray *)attributeNames uniformNames:(NSArray *)uniformNames
{
    self = [super init];
    
    if (!self) {
        return nil;
        
    }
    
    GLuint vertShader = 0, fragShader = 0;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // create shader program
    _program = glCreateProgram();
    
    // create and compile vertex shader
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:vertexShader ofType:@"vsh"];
    if (!compileShader(&vertShader, GL_VERTEX_SHADER, 1, vertShaderPathname)) {
        destroyShaders(vertShader, fragShader, _program);
        return nil;
    }
    
    // create and compile fragment shader
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:fragmentShader ofType:@"fsh"];
    if (!compileShader(&fragShader, GL_FRAGMENT_SHADER, 1, fragShaderPathname)) {
        destroyShaders(vertShader, fragShader, _program);
        return nil;
    }
    
    // attach vertex shader to program
    glAttachShader(_program, vertShader);
    
    // attach fragment shader to program
    glAttachShader(_program, fragShader);
    
    //参考《OpenGL es 3.0编程指南》 98页。这里是第2种方式
    // bind attribute locations; this needs to be done prior to linking
    [attributeNames enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        //根据idx，对输入变量生成一个‘location id’,与变量绑定在一起
        glBindAttribLocation(self->_program, (GLuint) idx, [obj cStringUsingEncoding:NSUTF8StringEncoding]);
    }];
    
    // link program
    if (!linkProgram(_program)) {
        destroyShaders(vertShader, fragShader, _program);
        return nil;
    }
    
    //参考《OpenGL es 3.0编程指南》 98页。这里是第3种方式
    NSMutableDictionary *uniformMap = [[NSMutableDictionary alloc] initWithCapacity:uniformNames.count];
    for (NSString *uniformName in uniformNames) {
        //如果已经绑定，返回对应的索引，否则，返回通用的索引
        GLuint location = glGetUniformLocation(_program, [uniformName cStringUsingEncoding:NSUTF8StringEncoding]);
        uniformMap[uniformName] = @(location);
    }
    _uniforms = uniformMap;
    
    // release vertex and fragment shaders
    if (vertShader) {
        glDeleteShader(vertShader);
        vertShader = 0;
    }
    if (fragShader) {
        glDeleteShader(fragShader);
        fragShader = 0;
    }
    
    return self;
}

- (void) freeGLResources
{
    glDeleteProgram(_program);
}

- (void) dealloc
{
    glDeleteProgram(_program);
}

- (GLuint) locationForUniform:(NSString *)uniform
{
    NSNumber *number = _uniforms[uniform];
    return [number unsignedIntValue];
}

@end
