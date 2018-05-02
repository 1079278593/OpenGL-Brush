//
//  CubicPathFunc.h
//  GLPaint
//
//  Created by 小明 on 2018/2/2.
//  三次贝塞尔曲线

#import <Foundation/Foundation.h>
#include <math.h>

typedef struct CubicBezierPath {
    CGPoint P0,C0,C1,P1;
    CGFloat length;
} CubicBezierPath;//三次(Cubic)贝塞尔曲线

@interface CubicPathFunc : NSObject

@property (nonatomic ,assign)CubicBezierPath pathPoints;
@property (nonatomic ,copy)NSArray<NSValue*> *points;

#pragma mark 速度方程
- (double)bezierPath_speed:(double)t;

#pragma mark 长度方程,使用Simpson积分算法
- (double)bezierPath_length:(double)t;

#pragma mark 根据t推导出匀速运动自变量t'的方程(使用牛顿切线法)
- (double)bezierPath_even:(double)t;

- (NSMutableArray *)linearInterpolation;
- (NSMutableArray *)pointsFromControlPoints:(NSMutableArray<NSValue*> *)points;

@end
