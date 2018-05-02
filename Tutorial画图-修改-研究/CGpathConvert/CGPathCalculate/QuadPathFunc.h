//
//  QuadPathFunc.h
//  GLPaint
//
//  Created by 小明 on 2018/2/2.
//  二次贝塞尔曲线

#import <Foundation/Foundation.h>
typedef struct QuadBezierPath {
    CGPoint P0,C0,P1;
    CGFloat length;
} QuadBezierPath;//二次(quad)贝塞尔曲线

@interface QuadPathFunc : NSObject

@property (nonatomic ,assign)QuadBezierPath pathPoints;

@end
