//
//  BezierPathModel.m
//  GLPaint
//
//  Created by 小明 on 2018/2/2.
//

#import "BezierPathModel.h"

@implementation BezierPathModel

- (CGPoint)P0 {
    return ((NSValue*)_points[0]).CGPointValue;
}
- (CGPoint)C0 {
    return ((NSValue*)_points[1]).CGPointValue;
}
- (CGPoint)C1 {
    return ((NSValue*)_points[2]).CGPointValue;
}
- (CGPoint)P1 {
    return ((NSValue*)_points[3]).CGPointValue;
}

@end
