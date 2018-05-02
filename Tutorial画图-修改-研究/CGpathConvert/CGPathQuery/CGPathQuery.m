//
//  CGPathQuery.m
//  CGPathQueryDemo
//
//  Created by Vivek Gani on 8/2/15.
//  Copyright (c) 2015 Vivek Gani. All rights reserved.
//

#import "CGPathQuery.h"
#import "CGPathQuery+Protected.h"
#import "CGPathQueryData.h"
#import "CAAnimation+Blocks.h"
#import <QuartzCore/QuartzCore.h>
//#import <AppKit/NSOpenGL.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface CGPathQuery () {
    EAGLContext * oglContext;
//    CARenderer * renderer;
    CALayer * backingLayer;
}

@property (assign, nonatomic) PathCalculationStateEnum pathCalculationState;

@end

@implementation CGPathQuery

- (instancetype) init
{
    self = [super init];
    if(self == nil) return nil;
    
    self.pathCalculationState = PathCalculationInit;
    
    return self;
}


- (NSError *) calculatePointsAndWaitAlongPath:(CGPathRef)path
                       completionStart:(CGFloat)zeroToOneCompletionStart
                         completionEnd:(CGFloat)zeroToOneCompletionEnd
                       completionDelta:(CGFloat)delta
{
    //
    // Calculated points and wait for the calculations to complete.
    // This will run until a timeout and number of retries has been performed.
    // The timeout/retries are used due to observations where the calculations will pause
    // indefinately.
    //
    // Root cause for this pause issue hasn't been found yet - it occurs intermittently and
    // doesn't seem like a deadlock issue despite appearing like one.
    //
    
    NSError * error;
    
    NSUInteger calculationTimeoutInSeconds = 10;
    NSUInteger maxRetries = 3;
    
    NSUInteger retriesPerformed = 0;
    bool calculationsCompleted = false;
    bool calculationsIncompleteAfterRetries = false;
    
    while(!calculationsCompleted ||
           calculationsIncompleteAfterRetries)
    {
        
        if(self.pathCalculationState == PathCalculationProcessing)
        {
            // teardown/refresh if we were processing
            self.pathCalculationState = PathCalculationInit;
        }
        
        error = [self calculatePointsAlongPath:path
                                         completionStart:zeroToOneCompletionStart
                                           completionEnd:zeroToOneCompletionEnd
                                         completionDelta:delta];

        //wait until we're done. perform check only if:
        // - not on the main thread to avoid deadlock
        // - no error resulted from the calculation call
        if( [[NSThread currentThread] isMainThread])
            calculationsCompleted = true; //calculations assumed complete
        
        if( (![[NSThread currentThread] isMainThread]) &&
           ((error == nil) || (error.code == 0)) )
        {
            NSUInteger secCount = 0;
            while( (self.pathCalculationState != PathCalculationDone) &&
                    (secCount < calculationTimeoutInSeconds) )
            {
                sleep(1);
                secCount++;
            }
            
            if(secCount > calculationTimeoutInSeconds)
            {
                if(retriesPerformed > maxRetries)
                {
                    calculationsIncompleteAfterRetries = true;
                }
                NSLog(@"ERROR: path calculations incomplete, retrying");
                retriesPerformed++;
            }
            else
            {
                calculationsCompleted = true;
            }
        }
    }
    
    if(calculationsIncompleteAfterRetries)
    {
        //add error information.
        NSLog(@"ERROR: calculations incomplete after %ld retries", maxRetries);
        NSString * errorDomain = [[NSString alloc] initWithFormat:@"%@", [self class]];
        error = [[NSError alloc] initWithDomain:errorDomain code:-1 userInfo:nil];
    }
    
    return error;
}

- (NSError *) calculatePointsAlongPath:(CGPathRef)path
      completionStart:(CGFloat)zeroToOneCompletionStart
                  completionEnd:(CGFloat)zeroToOneCompletionEnd
                  completionDelta:(CGFloat)delta

{
    //
    // Validation
    //
    NSString * errorDomain = [[NSString alloc] initWithFormat:@"%@", [self class]];

    if(self.pathCalculationState == PathCalculationProcessing)
    {
        NSLog(@"Can't perform new calculations while we're still processing - consider creating a new instance to do concurrent calculations");

        NSError * error = [[NSError alloc] initWithDomain:errorDomain code:-1 userInfo:nil];
        return error;
    }
    if(zeroToOneCompletionStart < 0.0 || zeroToOneCompletionStart > 1.0 )
    {
        NSError * error = [[NSError alloc] initWithDomain:errorDomain code:-1 userInfo:nil];
        return error;
    }
    if(zeroToOneCompletionEnd < 0.0 || zeroToOneCompletionEnd > 1.0 )
    {
        NSError * error = [[NSError alloc] initWithDomain:errorDomain code:-1 userInfo:nil];
        return error;
    }
    if(zeroToOneCompletionStart > zeroToOneCompletionEnd)
    {
        NSError * error = [[NSError alloc] initWithDomain:errorDomain code:-1 userInfo:nil];
        return error;
    }

    //
    // Calculate points along path
    //
    [self prepareOpenGL];

    self.pathCalculationState = PathCalculationProcessing;
    
    self.cgPathQueryData = [[CGPathQueryData alloc] init];
    self.cgPathQueryData.zeroToOneCompletionStart = zeroToOneCompletionStart;
    self.cgPathQueryData.zeroToOneCompletionEnd = zeroToOneCompletionEnd;
    self.cgPathQueryData.delta = delta;
    
    NSUInteger capacity = ((NSUInteger) ((zeroToOneCompletionEnd - zeroToOneCompletionStart) / delta)) + 1;
    self.cgPathQueryData.queryData = nil;
    self.cgPathQueryData.queryData = [[NSMutableArray alloc] initWithCapacity:capacity];//initWithObjects:[NSValue valueWithPoint:NSMakePoint(0.0, 0.0)] count:capacity];
    for(NSUInteger i = 0; i < capacity; i++)
        [self.cgPathQueryData.queryData setObject:[NSValue valueWithCGPoint:CGPointMake(0.0, 0.0)] atIndexedSubscript:i];
    
    __block NSUInteger finishCount = 1;
    
    for(NSUInteger i = 0; i < capacity; i++)
    {
        __block CALayer* pointLayer;
        CAKeyframeAnimation *animation;

        CGFloat completionPosition = zeroToOneCompletionStart + (delta * i);
        pointLayer = [CALayer layer];
        pointLayer.position = CGPointMake(0.0, 0.0);
        pointLayer.bounds = CGRectMake(0, 0, 1, 1);
//        pointLayer.backgroundColor = [CGColorCreateGenericRGB(1, 1, 0, 0)];
        pointLayer.backgroundColor = [UIColor colorWithRed:1/255.0 green:1/255.0 blue:0 alpha:0].CGColor;

        pointLayer.contents = [[UIImage alloc] init];
        [pointLayer setDrawsAsynchronously:YES];
        
        [backingLayer addSublayer:pointLayer];
        
        animation = [CAKeyframeAnimation animation];
        
        animation.keyPath = @"position";
        animation.timeOffset = completionPosition;
        animation.speed = 0.0;
        animation.duration = 1.000000000000001; //this needs to be set slightly greater than 1.0 as setting just 1.0 will yield the wrong point at the end when endPosition is 1.0.
        animation.path = path;
        [animation setRemovedOnCompletion:YES];
        
        [animation setCompletion:^(BOOL finished){
            if(pointLayer == nil)
                return;
            
            CGFloat x = ((CALayer *)pointLayer.presentationLayer).position.x;
            CGFloat y = ((CALayer *)pointLayer.presentationLayer).position.y;
            
            [self.cgPathQueryData.queryData setObject:[NSValue valueWithCGPoint:CGPointMake(x, y)] atIndexedSubscript:i];
            
            [pointLayer removeFromSuperlayer];
            pointLayer = nil;
            
//            NSLog(@"x: %f y: %f completePos = %f cnt = %ld finished: %d ", x, y, completionPosition, finishCount, finished ? 1: 0);

            finishCount++;
            if(finishCount >= capacity)
            {
                self.pathCalculationState = PathCalculationDone;
                //TODO: add notification of completion via delegate method
            }
        }];
        
        [pointLayer addAnimation:animation forKey:[[NSNumber numberWithFloat:completionPosition] stringValue] ];
        [pointLayer addAnimation:animation forKey:[[NSNumber numberWithFloat:completionPosition] stringValue] ];//NOTE: addAnimation called twice because calling once sometimes doesn't trigger animationDidStop - calling twice will trigger two notifications but we'll ignore the second one. Variations such as calling twice only the first time have shown unreliable depending on the number of times animation is called.
    }
    
    return nil;
}


- (NSValue *) pointAlongPathAtCompletion:(CGFloat)zeroToOneCompletion
                       error:(NSError *)error
{
    NSString * errorDomain = [[NSString alloc] initWithFormat:@"%@", [self class]];

    if(self.pathCalculationState == PathCalculationInit)
    {
        NSLog(@"Path calculations haven't happened yet");
        
        NSError * error = [[NSError alloc] initWithDomain:errorDomain code:-1 userInfo:nil];
        return nil;
    }
    if(self.pathCalculationState == PathCalculationProcessing)
    {
        NSLog(@"Path calculations are still being processed");
        
        NSError * error = [[NSError alloc] initWithDomain:errorDomain code:-1 userInfo:nil];
        return nil;
    }
    if(zeroToOneCompletion < self.cgPathQueryData.zeroToOneCompletionStart)
    {
        NSLog(@"completion value less than start value");

        NSError * error = [[NSError alloc] initWithDomain:errorDomain code:-1 userInfo:nil];
        return nil;
    }
    if(zeroToOneCompletion > self.cgPathQueryData.zeroToOneCompletionEnd)
    {
        NSLog(@"completion value greater than end value");
        
        NSError * error = [[NSError alloc] initWithDomain:errorDomain code:-1 userInfo:nil];
        return nil;
    }
    
    NSUInteger startIndex = (NSUInteger) ((zeroToOneCompletion - self.cgPathQueryData.zeroToOneCompletionStart) / self.cgPathQueryData.delta);
    
    NSUInteger endIndex = startIndex + 1;
    if(endIndex >= [self.cgPathQueryData.queryData count])
    {
        //just return the final value.
        return self.cgPathQueryData.queryData[startIndex];
    }

    CGPoint startIndexPointPosition = [self.cgPathQueryData.queryData[startIndex] CGPointValue];
    CGPoint endIndexPointPosition = [self.cgPathQueryData.queryData[endIndex] CGPointValue];

    CGFloat startIndexCalcPt = self.cgPathQueryData.zeroToOneCompletionStart + (startIndex * self.cgPathQueryData.delta);
    CGFloat startIndexBias = 1.0 - ((zeroToOneCompletion - startIndexCalcPt) / self.cgPathQueryData.delta);
    
    CGFloat averagedX = (startIndexPointPosition.x * startIndexBias) + (endIndexPointPosition.x * (1.0 - startIndexBias));
    CGFloat averagedY = (startIndexPointPosition.y * startIndexBias) + (endIndexPointPosition.y * (1.0 - startIndexBias));
    
    return [NSValue valueWithCGPoint:CGPointMake(averagedX, averagedY)];
}

- (void) prepareOpenGL
{
    
    [CATransaction begin];
    backingLayer = [CALayer layer];
    backingLayer.bounds = CGRectMake(0, 0, 1, 1);
    [backingLayer setDrawsAsynchronously:NO];
    
    
    [CATransaction commit];
}

- (void) loadCachedPointValues:(CGPathQueryData *)cgPathQueryData
{
    //
    //TODO: make sure we're not processing right now
    
    //reset query data
    self.cgPathQueryData = cgPathQueryData;
    self.pathCalculationState = PathCalculationDone;
}



@end
