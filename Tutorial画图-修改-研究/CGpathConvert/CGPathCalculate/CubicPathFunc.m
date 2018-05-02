//
//  CubicPathFunc.m
//  GLPaint
//
//  Created by 小明 on 2018/2/2.
//

#import "CubicPathFunc.h"

@interface CubicPathFunc () {
    //曲线总长度
    double total_length;
    //曲线分割的份数
    int STEP;
}

@end

@implementation CubicPathFunc

- (id)init {
    self = [super init];
    if (self) {
        total_length = 0.0;
        STEP = 40;
    }
    return self;
}
///t是沿着贝塞尔曲线运动的某个时刻
#pragma mark x坐标方程
- (double)bezierPath_x:(double)t {
    double it = 1-t;
    CGFloat P0_x = _pathPoints.P0.x,C0_x = _pathPoints.C0.x,C1_x = _pathPoints.C1.x,P1_x = _pathPoints.P1.x;
    return it*it*it*P0_x + 3*it*it*t*C0_x + 3*it*t*t*C1_x + t*t*t*P1_x;
    //    return it*it*it*P0.x + 3*it*it*t*P1.x + 3*it*t*t*P2.x + t*t*t*P3.x;
}

#pragma mark y坐标方程
- (double)bezierPath_y:(double)t {
    double it = 1-t;
    CGFloat P0_y = _pathPoints.P0.y,C0_y = _pathPoints.C0.y,C1_y = _pathPoints.C1.y,P1_y = _pathPoints.P1.y;
    return it*it*it*P0_y + 3*it*it*t*C0_y + 3*it*t*t*C1_y + t*t*t*P1_y;
    //    return it*it*it*P0.y + 3*it*it*t*P1.y + 3*it*t*t*P2.y + t*t*t*P3.y;
}

#pragma mark x坐标速度方程
- (double)bezierPath_speedX:(double)t {
    double it = 1-t;
    CGFloat P0_x = _pathPoints.P0.x,C0_x = _pathPoints.C0.x,C1_x = _pathPoints.C1.x,P1_x = _pathPoints.P1.x;
    return -3*P0_x*it*it + 3*C0_x*it*it - 6*C0_x*it*t + 6*C1_x*it*t - 3*C1_x*t*t + 3*P1_x*t*t;
    //    return -3*P0.x*it*it + 3*P1.x*it*it - 6*P1.x*it*t + 6*P2.x*it*t - 3*P2.x*t*t + 3*P3.x*t*t;
}

#pragma mark y坐标速度方程
- (double)bezierPath_speedY:(double)t {
    double it = 1-t;
    CGFloat P0_y = _pathPoints.P0.y,C0_y = _pathPoints.C0.y,C1_y = _pathPoints.C1.y,P1_y = _pathPoints.P1.y;
    return -3*P0_y*it*it + 3*C0_y*it*it - 6*C0_y*it*t + 6*C1_y*it*t - 3*C1_y*t*t + 3*P1_y*t*t;
    //    return -3*P0.y*it*it + 3*P1.y*it*it - 6*P1.y*it*t + 6*P2.y*it*t - 3*P2.y*t*t + 3*P3.y*t*t;
}

#pragma mark - Public Method
#pragma mark 速度方程
- (double)bezierPath_speed:(double)t {
    double sx = [self bezierPath_speedX:t];
    double sy = [self bezierPath_speedY:t];
    return sqrt(sx*sx+sy*sy);
}

#pragma mark 长度方程,使用Simpson积分算法
///t是整个曲线的长度(0~1)
- (double)bezierPath_length:(double)t {
    
    //在总长度范围内，使用simpson算法的分割数
    static int TOTAL_SIMPSON_STEP = 10000;
    
    //分割份数：t值(0~1)，即最多分割份数：TOTAL_SIMPSON_STEP
    int stepCounts = (int)(TOTAL_SIMPSON_STEP*t);
    
    if(stepCounts & 1) stepCounts++;    //偶数
    if(stepCounts == 0) return 0.0;     //t为0时
    
    //将stepCounts分成两份，奇数点和偶数点，分别求速度和
    int halfCounts = stepCounts/2;
    double sum1=0.0, sum2=0.0;
    
    /*假设t = 0.5，
     *stepCounts = TOTAL_SIMPSON_STEP*t = 10000*0.5，如果不是偶数，加1变成偶数。
     *dStep = t/stepCounts = 0.5/(10000*0.5)，(stepCounts可能是奇数需要加1)
     实际约等于：dStep = 1.0/TOTAL_SIMPSON_STEP,
     */
    double dStep = t/stepCounts;
    
    //奇数点：速度和
    for(int i=0; i<halfCounts; i++) {
        sum1 += [self bezierPath_speed:(2*i+1)*dStep];
    }
    
    //偶数点：速度和
    for(int i=1; i<halfCounts; i++) {
        sum2 += [self bezierPath_speed:(2*i)*dStep];
    }
    
    //判断是否是直线
    //    if ([self isLinearWithStartPoint:_pathPoints.P0 endPoint:_pathPoints.P1 otherPoint:_pathPoints.C0]&&[self isLinearWithStartPoint:_pathPoints.P0 endPoint:_pathPoints.P1 otherPoint:_pathPoints.C1]) {
    //        CGFloat dx = _pathPoints.P0.x - _pathPoints.P1.x;
    //        CGFloat dy = _pathPoints.P0.y - _pathPoints.P1.y;
    //        return sqrt( dx*dx+dy*dy);
    //    }
    
    return ([self bezierPath_speed:0.0]+[self bezierPath_speed:1.0]+2*sum2+4*sum1)*dStep/3.0;
}

#pragma mark 根据t推导出匀速运动自变量t'的方程(使用牛顿切线法)
- (double)bezierPath_even:(double)t {
    
    /*
     * 传入的t是：n/STEP,STEP是分割的份数
     * total_length = [self bezierPath_length:1.0];
     */
    
    //len是：(n/STEP)*total_length
    double len = t*total_length; //如果按照匀速增长,此时对应的曲线长度
    
    double t1=t, t2=0;
    
    do {
        //经过打印，t1、t2的正常值大概为0~1，如果不是0~1，通常代表出现问题,导致无法拟合
        NSLog(@"t1=%lf,t2=%lf",t1,t2);
        
        if ([self bezierPath_speed:t1]) {
            t2 = t1 - ([self bezierPath_length:t1]-len)/[self bezierPath_speed:t1];
            
            if(fabs(t1-t2)<0.0000001) break;
            //            if(fabs(fabs(t1)-fabs(t2))<0.0000001) {
            //                break;
            //            }
            
            t1=t2;
        }else {
            break;
        }
        
        
    }while(true);
    
    return t2;
}

- (BOOL)isLinearWithStartPoint:(CGPoint)p0 endPoint:(CGPoint)p1 otherPoint:(CGPoint)p2{
    /*
     * 直线：y = kx + b
     * float k = (y2-y1)/(x2-x1);
     * float b = y1-k*x1;
     */
    
    //p0和p1，垂直于Y轴
    if ((p1.x - p0.x) == 0) {
        if ((p2.x - p0.x) == 0) {
            return YES;
        }else {
            return NO;
        }
    }
    
    //p0和p1，不垂直于Y轴情况
    float k = (p1.y-p0.y)/(p1.x-p0.x);
    float b = p0.y-k*p0.x;
    
    if (p2.y == (k*p2.x +b)) {
        return YES;
    }else {
        return NO;
    }
    
}

#pragma mark 线性插值
- (NSMutableArray *)linearInterpolation {
    
    //计算总长度
    total_length = [self bezierPath_length:1.0];
    
    NSMutableArray *points = [NSMutableArray arrayWithCapacity:STEP];
    for (int i = 0; i<STEP; i++) {
        NSLog(@"第%d份",i);
        //1.分成若干份数
        double t = (double)i/STEP;
        
        //2.求得匀速运动对应的t值(对应第n份，n/STEP)
        t = [self bezierPath_even:t];
        
        //3.根据贝塞尔曲线函数，求得取得此时的x,y坐标
        double x = [self bezierPath_x:t];
        double y = [self bezierPath_y:t];
        
        //4.取整
        //        CGPoint point = CGPointMake((int)(x+0.50), (int)(y+0.50));
        CGPoint point = CGPointMake((int)(x+0.0), (int)(y+0.0));
        [points addObject:[NSValue valueWithCGPoint:point]];
        
    }
    return points;
}

- (NSMutableArray *)pointsFromControlPoints:(NSMutableArray<NSValue*> *)points {
    self.points = points;
    
    
}
@end
