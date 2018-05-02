//
//  BezierPathFunc.h
//  GLPaint
//
//  Created by 小明 on 2018/2/2.
//  通用贝塞尔曲线：即任意阶贝塞尔曲线

#import <Foundation/Foundation.h>
#import "BezierPathModel.h"

@interface BezierPathFunc : NSObject

@property (nonatomic, strong)NSMutableArray *points;

+ (NSMutableArray *)pointsFromControlPoints:(NSMutableArray *)points precision:(int)count;
@end
