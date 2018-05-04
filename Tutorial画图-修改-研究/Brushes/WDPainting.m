//
//  WDPainting.m
//  GLPaint
//
//  Created by 小明 on 2018/5/2.
//

#import "WDPainting.h"

@implementation WDPainting

- (id) init
{
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
    // we don't want to notify when we're initing
    self.dimensions = CGSizeMake(512, 512);
    
    return self;
}

#pragma mark - 着色器
- (void) loadShaders
{
    NSString        *shadersJSONPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Shaders.json"];
    NSData          *JSONData = [NSData dataWithContentsOfFile:shadersJSONPath];
    NSError         *error = nil;
    NSDictionary    *shaderDict = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:&error];
    
    if (!shaderDict) {
        NSLog(@"Error loading 'Shaders.json': %@", error);
        return;
    }
    
    NSMutableDictionary *tempShaders = [NSMutableDictionary dictionary];
    
    for (NSString *key in shaderDict.keyEnumerator) {
        NSDictionary *description = shaderDict[key];
        NSString *vertex = description[@"vertex"];
        NSString *fragment = description[@"fragment"];
        NSArray *attributes = description[@"attributes"];
        NSArray *uniforms = description[@"uniforms"];
        
        WDShader *shader = [[WDShader alloc] initWithVertexShader:vertex
                                                   fragmentShader:fragment
                                                  attributesNames:attributes
                                                     uniformNames:uniforms];
        tempShaders[key] = shader;
    }
//    WDCheckGLError();
    
    _shaders = tempShaders;
}

- (WDShader *) getShader:(NSString *)shaderKey
{
    [EAGLContext setCurrentContext:self.context];
    return _shaders[shaderKey];
}

- (void) setDimensions:(CGSize)dimensions
{
    _dimensions = dimensions;
    mat4f_LoadOrtho(0, _dimensions.width, 0, _dimensions.height, -1.0f, 1.0f, projection_);
}

#pragma mark - 根据WDBrush生成笔刷纹理
- (WDTexture *) brushTexture
{
    NSLog(@"生成笔刷纹理");
    [EAGLContext setCurrentContext:self.context];
    
    if (self.brushTexture) {
        [self.brushTexture freeGLResources];//删除之前绑定的纹理：glDeleteTextures()
    }
    
    self.brush = [WDTexture alphaTextureWithImage:[WDStampGenerator stamp]];
    
    return self.brushTexture;
}

#pragma mark 根据WDBrush配置笔刷
- (void) configureBrush
{
    NSLog(@"配置笔刷");
    WDShader *brushShader = [self getShader:@"brush"];
    glUseProgram(brushShader.program);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, [self brushTexture].textureName);
    
    glUniform1i([brushShader locationForUniform:@"texture"], 0);
    glUniformMatrix4fv([brushShader locationForUniform:@"modelViewProjectionMatrix"], 1, GL_FALSE, projection_);
//    WDCheckGLError();
}

@end
