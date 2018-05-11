//
//  LYOpenGLManager.h
//  LearnAVFoundation
//
//  Created by loyinglin on 2017/8/22.
//  Copyright © 2017年 林伟池. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LYOpenGLManager : NSObject

+ (instancetype)shareInstance;

- (void)prepareToDraw:(CVPixelBufferRef)videoPixelBuffer andDestination:(CVPixelBufferRef)destPixelBuffer;

- (void)prepareToDrawDoubleVideo:(CVPixelBufferRef)videoPixelBuffer secondBuffer:(CVPixelBufferRef)secondVideoPixelBuffer andDestination:(CVPixelBufferRef)destPixelBuffer;
@end
