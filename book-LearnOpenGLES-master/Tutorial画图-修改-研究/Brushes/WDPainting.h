//
//  WDPainting.h
//  GLPaint
//
//  Created by 小明 on 2018/5/2.
//

#import <Foundation/Foundation.h>
#import "WDTexture.h"
#import "WDStampGenerator.h"

@interface WDPainting : NSObject {
    GLfloat                 projection_[16];
}

@property (nonatomic, readonly) EAGLContext *context;
@property (nonatomic) WDTexture *brush;

@property (nonatomic, readonly) NSDictionary *shaders;
@property (nonatomic, assign) CGSize dimensions;
@end
