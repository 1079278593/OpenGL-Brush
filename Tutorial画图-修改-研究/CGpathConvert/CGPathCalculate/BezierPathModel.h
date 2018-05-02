//
//  BezierPathModel.h
//  GLPaint
//
//  Created by 小明 on 2018/2/2.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, BezierPathType) {
    BezierPathTypeLine  = 2,    //2个控制点
    BezierPathTypeQuad  = 3,    //3个控制点
    BezierPathTypeCubic = 4     //4个控制点
};

@interface BezierPathModel : NSObject

@property (nonatomic, assign) BezierPathType type;
@property (nonatomic, strong) NSMutableArray *points;

@property (nonatomic, assign, readonly) CGPoint P0;
@property (nonatomic, assign, readonly) CGPoint C0;
@property (nonatomic, assign, readonly) CGPoint C1;//如果是二次曲线，则C1不赋值
@property (nonatomic, assign, readonly) CGPoint P1;

@end
