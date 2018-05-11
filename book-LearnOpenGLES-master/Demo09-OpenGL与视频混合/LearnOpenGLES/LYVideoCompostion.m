//
//  LYVideoCompostion.m
//  LearnAVFoundation
//
//  Created by loyinglin on 2017/8/22.
//  Copyright © 2017年 林伟池. All rights reserved.
//

#import "LYVideoCompostion.h"
#import "LYOpenGLManager.h"

@interface LYVideoCompostion ()

@end

@implementation LYVideoCompostion
{
    BOOL								_shouldCancelAllRequests;
    BOOL								_renderContextDidChange;
    dispatch_queue_t					_renderingQueue;
    dispatch_queue_t					_renderContextQueue;
    AVVideoCompositionRenderContext*	_renderContext;
    CVPixelBufferRef					_previousBuffer;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _renderingQueue = dispatch_queue_create("loying.lin.LYVideoCompostion.renderQueue", DISPATCH_QUEUE_SERIAL);
        _renderContextQueue = dispatch_queue_create("loying.lin.LYVideoCompostion.renderContextQueue", DISPATCH_QUEUE_SERIAL);
        _previousBuffer = nil;
        _renderContextDidChange = NO;
    }
    return self;
}

- (NSDictionary *)sourcePixelBufferAttributes {
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
              (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
              (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
    @autoreleasepool {
        dispatch_async(_renderingQueue,^() {
            // Check if all pending requests have been cancelled
            if (_shouldCancelAllRequests) {
                [request finishCancelledRequest];
            } else {
                NSError *err = nil;
                // Get the next rendererd pixel buffer
                CVPixelBufferRef resultPixels = [self newRenderedPixelBufferForRequest:request error:&err];
                
                if (resultPixels) {
                    // The resulting pixelbuffer from OpenGL renderer is passed along to the request
                    [request finishWithComposedVideoFrame:resultPixels];
                    CFRelease(resultPixels);
                } else {
                    [request finishWithError:err];
                }
            }
        });
    }
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {
    dispatch_sync(_renderContextQueue, ^() {
        _renderContext = newRenderContext;
        _renderContextDidChange = YES;
    });
}

- (void)cancelAllPendingVideoCompositionRequests
{
    // pending requests will call finishCancelledRequest, those already rendering will call finishWithComposedVideoFrame
    _shouldCancelAllRequests = YES;
    
    dispatch_barrier_async(_renderingQueue, ^() {
        // start accepting requests again
        _shouldCancelAllRequests = NO;
    });
}



- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut
{
    CVPixelBufferRef destBufferRef = [_renderContext newPixelBuffer];
    if (request.sourceTrackIDs.count > 0)
    {
        // 视频混合的处理，根据trackIDs处理视频混合
        if (request.sourceTrackIDs.count > 1) {
            CVPixelBufferRef videoBufferRef = [request sourceFrameByTrackID:[[request.sourceTrackIDs objectAtIndex:0] intValue]];
            CVPixelBufferRef secondVideoBufferRef = [request sourceFrameByTrackID:[[request.sourceTrackIDs objectAtIndex:1] intValue]];
            if (videoBufferRef && secondVideoBufferRef) {
                [[LYOpenGLManager shareInstance] prepareToDrawDoubleVideo:videoBufferRef secondBuffer:secondVideoBufferRef andDestination:destBufferRef];
            }
            
        } else {
            CVPixelBufferRef videoBufferRef = [request sourceFrameByTrackID:[[request.sourceTrackIDs objectAtIndex:0] intValue]];
            if (videoBufferRef) {
                [[LYOpenGLManager shareInstance] prepareToDraw:videoBufferRef andDestination:destBufferRef];
            }
        }
        
    }
    return destBufferRef;
}

@end
