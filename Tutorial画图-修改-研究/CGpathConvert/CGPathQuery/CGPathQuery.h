//
//  CGPathQuery.h
//  CGPathQueryDemo
//
//  Created by Vivek Gani on 8/2/15.
//  Copyright (c) 2015 Vivek Gani. All rights reserved.
//

/*
 *从Mac OS迁移过来，为了编译通过删除了一些代码，这里只用作参考部分方法
 
 */
#import <Foundation/Foundation.h>

@class CGPathQueryData;

@interface CGPathQuery : NSObject

- (NSError *) calculatePointsAndWaitAlongPath:(CGPathRef)path
                              completionStart:(CGFloat)zeroToOneCompletionStart
                                completionEnd:(CGFloat)zeroToOneCompletionEnd
                              completionDelta:(CGFloat)delta;

- (NSError *) calculatePointsAlongPath:(CGPathRef)path
                       completionStart:(CGFloat)zeroToOneCompletionStart
                         completionEnd:(CGFloat)zeroToOneCompletionEnd
                       completionDelta:(CGFloat)delta;

- (void) loadCachedPointValues:(CGPathQueryData *)cgPathQueryData;

- (NSValue *) pointAlongPathAtCompletion:(CGFloat)zeroToOneCompletion
                                   error:(NSError *)error;

typedef enum
{
    PathCalculationInit,
    PathCalculationProcessing,
    PathCalculationDone
} PathCalculationStateEnum;

@end
