//
//  BezierPathFunc.m
//  GLPaint
//
//  Created by 小明 on 2018/2/2.
//

#import "BezierPathFunc.h"

@implementation BezierPathFunc

/**
 * @param points      贝塞尔曲线控制点坐标
 * @param count     精度，需要计算的该条贝塞尔曲线上的点的数目
 * @return          该条贝塞尔曲线上的点（二维坐标）
 * 参考链接：http://blog.csdn.net/aimeimeits/article/details/72809382
 */
+ (NSMutableArray *)pointsFromControlPoints:(NSMutableArray *)points precision:(int)count {
    //维度，坐标轴数（二维坐标(x,y)，三维坐标(x,y,z)...）
    int dimension = (int)((NSArray *)points[0]).count;
    
    //贝塞尔曲线：控制点数（阶数）
    int number = (int)points.count;//int number = poss.length;
    
    //控制点数不小于 2 ，至少为二维坐标系
    if (number < 2 || dimension < 2) {
        return nil;
    }
    
    //float[][] result = new float[precision][dimersion];
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];

    //计算杨辉三角
    NSArray *mi = [BezierPathFunc pascalTriangle:number];
    
    //计算坐标点
    for (int i = 0; i < count; i++) {
        float t = (float) i / count;
        
        NSMutableArray *dims = [NSMutableArray arrayWithCapacity:dimension];
        for (int j = 0; j < dimension; j++) {
            float temp = 0.0f;
            for (int k = 0; k < number; k++) {
                /**
                 N = 3: P = (1-t)^2*P0 + 2*(1-t)*t*P1 + t^2*P2
                 N = 4: P = (1-t)^3*P0 + 3*(1-t)^2*t*P1 + 3(1-t)*t^2*P2 + t^3*P3
                 N = 5: P = (1-t)^4*P0 + 4*(1-t)^3*t*P1 + 6(1-t)^2*t^2*P2 + 4*(1-t)*t^3*P3 + t^4*P4
                */
                temp += pow((1.0 - t), (number - k - 1.0)) * [points[k][j] floatValue] * pow(t, (float)k) * [mi[k] floatValue];
            }
            [dims addObject:@(temp)];
        }
        [result addObject:dims];
    }
    
    [BezierPathFunc pathLength:result];
    
    return result;
}

///当点数足够密时，长度约等于数值积分
+ (CGFloat)pathLength:(NSArray *)points {
    CGFloat sum = 0;
    NSArray *lastPoint = points[0];
    for (NSArray *point in points) {
        CGFloat length = 0;
        for (int i = 0; i<point.count; i++) {
            length += pow([point[i] floatValue] - [lastPoint[i] floatValue], 2);
        }
        length = sqrt(length);
        sum += length;
        lastPoint = point;
    }
    
    NSLog(@"任意阶长度：%f",sum);
    return sum;
}

#pragma mark - Private Method
+ (NSArray *)pascalTriangle:(int)n {

    int a[n][n]; /*定义二维数组a[n][n]*/
    
    printf("%d行杨辉三角如下：\n",n);
    
    //对数组进行赋值
    for(int m = 0;m<n;m++)
    {
        for(int j = 0;j<=m;j++)//每一层的个数都是小于等于层数的，m代表层数，j代表着第几个数
        {
            if(j==0||m==j) {
                //每一层的开头都是1，m==j的时候也是1,必须要这个，凡事都得有个开头
                a[m][j]=1;
            }else {
                //这个就是递推的方法了，例如3=1+2，3的坐标就是3[3,1]=1[2,0]+2[2,1];
                a[m][j]=a[m-1][j-1]+a[m-1][j];
            }
        }
    }
    
    //输出数组
    for(int i=0;i<n;i++)
    {
        for(int l=i;l<n;l++)//这个主要是打空格，好看一点，去掉就是直角三角形了
        {
            printf("  ");
        }
        for (int j = 0; j<=i; j++)//这个就是打印数组了，每层循环几次就几个
        {
            printf("%4d",a[i][j]);//不懂的可以把n替换成10，更加清楚点
        }
        printf("\n");//每层换行
    }
    
    //获取第n行,即：i==n-1 时
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:0];
    for (int i = 0; i<n; i++) {
        [result addObject:@(a[n-1][i])];
    }

    return result;
}

@end
