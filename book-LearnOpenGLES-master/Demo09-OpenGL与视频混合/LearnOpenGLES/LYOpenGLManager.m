//
//  LYOpenGLManager.m
//  LearnAVFoundation
//
//  Created by loyinglin on 2017/8/22.
//  Copyright © 2017年 林伟池. All rights reserved.
//

#import "LYOpenGLManager.h"
#import <GLKit/GLKit.h>
#import <OpenGLES/ES2/glext.h>

static const GLfloat baseVertices[] =
{
    -1, -1, 0.0, 0.0, 0.0,  // 左下
    1, -1, 0.0, 1.0, 0.0,  // 右下
    -1, 1, 0.0, 0.0, 1.0,  // 左上
    
    1, -1, 0.0, 1.0, 0.0, //右下
    -1,  1, 0.0, 0.0, 1.0, //左上
    1,  1, 0.0, 1.0, 1.0 //右上
};


static const GLfloat firstVertices[] =
{
    0, -1, 0.0, 0.0, 0.0,  // 左下
    1, -1, 0.0,1.0, 0.0,  // 右下
    0, 1, 0.0,0.0, 1.0,  // 左上
    
    1, -1, 0.0,1.0, 0.0, //右下
    0,  1, 0.0,0.0, 1.0, //左上
    1,  1, 0.0,1.0, 1.0 //右上
};


static const GLfloat secondVertices[] =
{
    -1, -1, 0.0,0.0, 0.0,  // 左下
    0, -1, 0.0,1.0, 0.0,  // 右下
    -1, 1, 0.0,0.0, 1.0,  // 左上
    
    0, -1, 0.0,1.0, 0.0, //右下
    -1,  1, 0.0,0.0, 1.0, //左上
    0,  1, 0.0,1.0, 1.0 //右上
};

@implementation LYOpenGLManager
{
    GLKBaseEffect *baseEffect;
    CVOpenGLESTextureRef videoTextureRef;
    CVOpenGLESTextureRef secondVideoTextureRef;
    CVOpenGLESTextureCacheRef videoTextureCache;
    CVOpenGLESTextureRef destTextureRef;
    EAGLContext *context;
    GLuint frameBufferId;
}

+ (instancetype)shareInstance {
    static id test;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        test = [[[self class] alloc] init];
    });
    return test;
}

- (id)init {
    self = [super init];
    if (self) {
        [self customInit];
        
    }
    return self;
}


- (void)customInit {
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:context];
    glGenFramebuffers(1, &frameBufferId);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBufferId);
    baseEffect = [[GLKBaseEffect alloc] init];
    CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &videoTextureCache);
}


- (void)prepareToDraw:(CVPixelBufferRef)videoPixelBuffer andDestination:(CVPixelBufferRef)destPixelBuffer {
    // 准备绘制相关
    if ([EAGLContext currentContext] != context) {
        [EAGLContext setCurrentContext:context];
    }
    glBindFramebuffer(GL_FRAMEBUFFER, frameBufferId);
    [self cleanUpTextures];
    glViewport(0, 0, (GLsizei)CVPixelBufferGetWidth(destPixelBuffer), (GLsizei)CVPixelBufferGetHeight(destPixelBuffer));
    
    BOOL success = NO;
    do {
        CVReturn ret;
        
        // 配置渲染目标
        ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           videoTextureCache,
                                                           destPixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RGBA,
                                                           (int)CVPixelBufferGetWidth(destPixelBuffer),
                                                           (int)CVPixelBufferGetHeight(destPixelBuffer),
                                                           GL_BGRA,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &destTextureRef);
        if (ret) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", ret);
            break;
        }
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(destTextureRef), CVOpenGLESTextureGetName(destTextureRef), 0);
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Error at glFramebufferTexture2D");
            break;
        }
        
        // 上传图像
        ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           videoTextureCache,
                                                           videoPixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RGBA,
                                                           (int)CVPixelBufferGetWidth(videoPixelBuffer),
                                                           (int)CVPixelBufferGetHeight(videoPixelBuffer),
                                                           GL_BGRA,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &videoTextureRef);
        
        if (ret) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", ret);
            break;
        }
        glBindTexture(CVOpenGLESTextureGetTarget(videoTextureRef), CVOpenGLESTextureGetName(videoTextureRef));
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        baseEffect.texture2d0.name = CVOpenGLESTextureGetName(videoTextureRef);
        baseEffect.texture2d0.target = CVOpenGLESTextureGetTarget(videoTextureRef);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, baseVertices);
        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, baseVertices + 3);
        [baseEffect prepareToDraw];
        
        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        glDrawArrays(GL_TRIANGLES, 0, 6); // 6个顶点，2个三角形
        
        success = YES;
    } while (NO);
    
    if (!success) {
        NSLog(@"render is %@", success ? @"success":@"fail");
    }
}

- (void)prepareToDrawDoubleVideo:(CVPixelBufferRef)videoPixelBuffer secondBuffer:(CVPixelBufferRef)secondVideoPixelBuffer andDestination:(CVPixelBufferRef)destPixelBuffer {
    
    // 准备绘制相关
    if ([EAGLContext currentContext] != context) {
        [EAGLContext setCurrentContext:context];
    }
    glBindFramebuffer(GL_FRAMEBUFFER, frameBufferId);
    [self cleanUpTextures];
    glViewport(0, 0, (GLsizei)CVPixelBufferGetWidth(destPixelBuffer), (GLsizei)CVPixelBufferGetHeight(destPixelBuffer));
    
    BOOL success = NO;
    do {
        CVReturn ret;
        
        // 配置渲染目标
        ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           videoTextureCache,
                                                           destPixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RGBA,
                                                           (int)CVPixelBufferGetWidth(destPixelBuffer),
                                                           (int)CVPixelBufferGetHeight(destPixelBuffer),
                                                           GL_BGRA,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &destTextureRef);
        if (ret) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", ret);
            break;
        }
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLESTextureGetTarget(destTextureRef), CVOpenGLESTextureGetName(destTextureRef), 0);
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Error at glFramebufferTexture2D");
            break;
        }
        
        
        
        // 上传图像
        ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           videoTextureCache,
                                                           videoPixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RGBA,
                                                           (int)CVPixelBufferGetWidth(videoPixelBuffer),
                                                           (int)CVPixelBufferGetHeight(videoPixelBuffer),
                                                           GL_BGRA,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &videoTextureRef);
        
        if (ret) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", ret);
            break;
        }
        glBindTexture(CVOpenGLESTextureGetTarget(videoTextureRef), CVOpenGLESTextureGetName(videoTextureRef));
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        baseEffect.texture2d0.name = CVOpenGLESTextureGetName(videoTextureRef);
        baseEffect.texture2d0.target = CVOpenGLESTextureGetTarget(videoTextureRef);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, firstVertices);
        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, firstVertices + 3);
        [baseEffect prepareToDraw];
        
        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        glDrawArrays(GL_TRIANGLES, 0, 6); // 6个顶点，2个三角形
        
        
        
        // 上传图像
        ret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           videoTextureCache,
                                                           secondVideoPixelBuffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           GL_RGBA,
                                                           (int)CVPixelBufferGetWidth(secondVideoPixelBuffer),
                                                           (int)CVPixelBufferGetHeight(secondVideoPixelBuffer),
                                                           GL_BGRA,
                                                           GL_UNSIGNED_BYTE,
                                                           0,
                                                           &secondVideoTextureRef);
        
        if (ret) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", ret);
            break;
        }
        glBindTexture(CVOpenGLESTextureGetTarget(secondVideoTextureRef), CVOpenGLESTextureGetName(secondVideoTextureRef));
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        baseEffect.texture2d0.name = CVOpenGLESTextureGetName(secondVideoTextureRef);
        baseEffect.texture2d0.target = CVOpenGLESTextureGetTarget(secondVideoTextureRef);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, secondVertices);
        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, secondVertices + 3);
        [baseEffect prepareToDraw];
        
        glDrawArrays(GL_TRIANGLES, 0, 6); // 6个顶点，2个三角形
        
        
        
        success = YES;
    } while (NO);
    
    if (!success) {
        NSLog(@"render is %@", success ? @"success":@"fail");
    }
}

- (void)cleanUpTextures
{
    if (videoTextureRef) {
        CFRelease(videoTextureRef);
        videoTextureRef = NULL;
    }
    
    if (destTextureRef) {
        CFRelease(destTextureRef);
        destTextureRef = NULL;
    }
    
    if (secondVideoTextureRef) {
        CFRelease(secondVideoTextureRef);
        secondVideoTextureRef = NULL;
    }
    
    CVOpenGLESTextureCacheFlush(videoTextureCache, 0);
}

@end
