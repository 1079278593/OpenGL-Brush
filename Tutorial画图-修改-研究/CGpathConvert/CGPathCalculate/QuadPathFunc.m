//
//  QuadPathFunc.m
//  GLPaint
//
//  Created by 小明 on 2018/2/2.
//

#import "QuadPathFunc.h"

#define ax [self bezierPath_ax]
#define ay [self bezierPath_ay]
#define bx [self bezierPath_bx]
#define by [self bezierPath_by]
#define A [self bezierPath_A]
#define B [self bezierPath_B]
#define C [self bezierPath_C]
#define L(t) [self line:t]
#define S(t) [self speed:t]

@interface QuadPathFunc () {
    //曲线总长度
    double total_length;
    //曲线分割的份数
    int STEP;
}
@end

@implementation QuadPathFunc

- (id)init {
    self = [super init];
    if (self) {
        total_length = 0.0;
        STEP = 40;
    }
    return self;
}

- (int)bezierPath_ax {
    return _pathPoints.P0.x-2*_pathPoints.C0.x+_pathPoints.P1.x;
    //    return P0.x-2*P1.x+P2.x;
}

- (int)bezierPath_ay {
    return _pathPoints.P0.y-2*_pathPoints.C0.y+_pathPoints.P1.y;
    //    return P0.y-2*P1.y+P2.y;
}

- (int)bezierPath_bx {
    return 2*_pathPoints.C0.x-2*_pathPoints.P0.x;
    //    return 2*P1.x-2*P0.x;
}

- (int)bezierPath_by {
    return 2*_pathPoints.C0.y-2*_pathPoints.P0.y;
    //    return 2*P1.y-2*P0.y;
}

/**
 double A = 4*(ax*ax+ay*ay);
 
 double B = 4*(ax*bx+ay*by);
 
 double C = bx*bx+by*by;
 */
- (int)bezierPath_A {
    return 4*(pow(ax, 2)+pow(ay, 2));
}

- (int)bezierPath_B {
    return 4*(ax*bx+ay*by);
}
- (int)bezierPath_C {
    return (pow(bx, 2)+pow(by, 2));
}

#pragma mark - 3455

/*
 *速度函数
 s(t_) = Sqrt[A*t*t+B*t+C]
 */
- (double)speed:(double)t {
    return sqrt(A*t*t+B*t+C);
}

/*
 * 长度函数
 L(t) = Integrate[s[t], t]
 
 L(t_) = ((2*Sqrt[A]*(2*A*t*Sqrt[C + t*(B + A*t)] + B*(-Sqrt[C] + Sqrt[C + t*(B + A*t)])) +
 
 (B^2 - 4*A*C) (Log[B + 2*Sqrt[A]*Sqrt[C]] - Log[B + 2*A*t + 2 Sqrt[A]*Sqrt[C + t*(B + A*t)]]))
 
 /(8* A^(3/2)));
 
 */
- (double)line:(double)t {
    
    double temp1 = sqrt(C+t*(B+A*t));
    
    double temp2 = (2*A*t*temp1+B*(temp1-sqrt(C)));
    
    double temp3 = log(B+2*sqrt(A)*sqrt(C));
    
    double temp4 = log(B+2*A*t+2*sqrt(A)*temp1);
    
    double temp5 = 2*sqrt(A)*temp2;
    
    double temp6 = (B*B-4*A*C)*(temp3-temp4);
    
    return (temp5+temp6)/(8*pow(A,1.5));
}

/*
 *  长度函数反函数，使用牛顿切线法求解
 *  X(n+1) = Xn - F(Xn)/F'(Xn)
 */

- (double)invertLine:(double)t line:(double)l {
    
    double t1=t, t2;
    
    do{
        t2 = t1 - (L(t1)-l)/S(t1);
        if(fabs(t1-t2)<0.000001) break;
        t1=t2;
    }while(true);
    
    return t2;
}

//-------------------------------------------------------------------------------------
- (NSMutableArray *)caculate {
    
    total_length = L(1.0);
    
    NSMutableArray *points = [NSMutableArray arrayWithCapacity:STEP];
    for (int i = 0; i<STEP; i++) {
        double t = (double)i/STEP;
        //如果按照线形增长,此时对应的曲线长度
        double l = t*total_length;
        //根据L函数的反函数，求得l对应的t值
        t = [self invertLine:t line:l];
        
        //根据贝塞尔曲线函数，求得取得此时的x,y坐标
        //        double x = (1-t)*(1-t)*P0.x +2*(1-t)*t*P1.x + t*t*P2.x;
        //        double y = (1-t)*(1-t)*P0.y +2*(1-t)*t*P1.y + t*t*P2.y;
        double x = (1-t)*(1-t)*_pathPoints.P0.x +2*(1-t)*t*_pathPoints.C0.x + t*t*_pathPoints.P1.x;
        double y = (1-t)*(1-t)*_pathPoints.P0.y +2*(1-t)*t*_pathPoints.C0.y + t*t*_pathPoints.P1.y;
        
        //取整
        CGPoint point = CGPointMake((int)(x+0.0), (int)(y+0.0));
        [points addObject:[NSValue valueWithCGPoint:point]];
    }
    
    return points;
}

@end
