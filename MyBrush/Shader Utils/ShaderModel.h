//
//  ShaderModel.h
//  MyBrush
//
//  Created by 小明 on 2018/5/15.
//  Copyright © 2018年 laihua. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>
#import "ShaderUtil.h"

@interface ShaderModel : NSObject

@property (nonatomic, readonly) GLuint program;
@property (nonatomic, readonly) NSDictionary *uniforms;


+ (ShaderModel *) shaderWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader attributesNames:(NSArray *)attributeNames uniformNames:(NSArray *)uniformNames;

- (id) initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader
            attributesNames:(NSArray *)attributeNames uniformNames:(NSArray *)uniformNames;

- (GLuint) locationForUniform:(NSString *)uniform;

- (void) freeGLResources;

@end
