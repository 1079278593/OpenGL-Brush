//
//  VectorGeometry.m
//
//  Created by 李林 on 2018/1/8.
//  Copyright © 2018年 iLaihua. All rights reserved.
//

#import "VectorGeometry.h"

#pragma mark - Internal

double getRotateAngle(double x1, double y1, double x2, double y2)
{
    const double epsilon = 1.0e-6;
    const double nyPI = acos(-1.0);
    double dist, dot, degree, angle;
    
    // normalize
    dist = sqrt( x1 * x1 + y1 * y1 );
    x1 /= dist;
    y1 /= dist;
    dist = sqrt( x2 * x2 + y2 * y2 );
    x2 /= dist;
    y2 /= dist;
    // dot product
    dot = x1 * x2 + y1 * y2;
    if ( fabs(dot-1.0) <= epsilon )
        angle = 0.0;
    else if ( fabs(dot+1.0) <= epsilon )
        angle = nyPI;
    else {
        double cross;
        
        angle = acos(dot);
        //cross product
        cross = x1 * y2 - x2 * y1;
        // vector p2 is clockwise from vector p1
        // with respect to the origin (0.0)
        if (cross < 0 ) {
            angle = 2 * nyPI - angle;
        }
    }
    degree = angle *  180.0 / nyPI;
    return degree;
}

CGFloat GetTwoVectorAngle(CGPoint startVector , CGPoint endVector)
{
    return M_PI * getRotateAngle(endVector.x, endVector.y, startVector.x, startVector.y)/180;
}

CGFloat GetTwoVectorAngle1(CGPoint startVector , CGPoint endVector)
{
    if (endVector.y >= 0) {
        return acos(endVector.x/sqrt(endVector.x*endVector.x+endVector.y*endVector.y));
    }else{
        return -acos(endVector.x/sqrt(endVector.x*endVector.x+endVector.y*endVector.y));
    }
}
CGFloat GetTwoVectorAngle2(CGPoint startVector , CGPoint endVector)
{
    CGPoint Xpoint = CGPointMake(startVector.x + 100, startVector.y);
    
    CGFloat a = endVector.x - startVector.x;
    CGFloat b = endVector.y - startVector.y;
    CGFloat c = Xpoint.x - startVector.x;
    CGFloat d = Xpoint.y - startVector.y;
    
    CGFloat rads = acos(((a*c) + (b*d)) / ((sqrt(a*a + b*b)) * (sqrt(c*c + d*d))));
    
    if (startVector.y>endVector.y) {
        rads = -rads;
    }
    return rads;
}


double getTwoVectorRotateAngle(CGPoint startVector , CGPoint endVector ,bool clockwise)
{
    CGFloat x1 = startVector.x;
    CGFloat y1 = startVector.y;
    CGFloat x2 = endVector.x;
    CGFloat y2 = endVector.y;
    
    
    const double epsilon = 1.0e-6;
    const double nyPI = acos(-1.0);
    double dist, dot, angle;
    
    // normalize
    dist = sqrt( x1 * x1 + y1 * y1 );
    x1 /= dist;
    y1 /= dist;
    dist = sqrt( x2 * x2 + y2 * y2 );
    x2 /= dist;
    y2 /= dist;
    // dot product
    dot = x1 * x2 + y1 * y2;
    if ( fabs(dot-1.0) <= epsilon )
        angle = 0.0;
    else if ( fabs(dot+1.0) <= epsilon )
        angle = nyPI;
    else {
        double cross;
        angle = acos(dot);
        //cross product
        cross = x1 * y2 - x2 * y1;
        // vector p2 is clockwise from vector p1
        // with respect to the origin (0.0)
        if (cross < 0 ) {
            angle = 2 * nyPI - angle;
        }
    }
    if (clockwise) {
        return 2*M_PI - angle;
    }
    return angle;
}

