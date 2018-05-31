//
//  LineGeometry.m
//
//  Created by Stephan Michels on 21.07.12.
//
//

#import "LineGeometry.h"

typedef struct line {
    CGPoint point1;
    CGPoint point2;
} line;

BOOL IsPointOnSegment(CGPoint p,CGPoint p1,CGPoint p2){
    //差积是否为0，判断是否在同一直线上
    //trace(( p1.x -p.x )*( p2.y-p.y) -( p2.x -p.x )*( p1.y-p.y));
    if (( p1.x -p.x )*( p2.y-p.y) -( p2.x -p.x )*( p1.y-p.y)!=0)
    {
        return NO;
    }
    //判断是否在线段上
    if ((p.x > p1.x && p.x > p2.x) || (p.x < p1.x && p.x < p2.x))
    {
        return NO;
    }
    if ((p.y > p1.y && p.y > p2.y) || (p.y < p1.y && p.y < p2.y))
    {
        return NO;
    }
    return YES;
}

CGFloat LineGetLength(CGPoint p1, CGPoint p2) {
    CGFloat dx = p2.x - p1.x;
	CGFloat dy = p2.y - p1.y;
	
    if (dx == 0.0f) {
        return ABS(dy);
    } else if (dy == 0.0f) {
        return ABS(dx);
    }
    
    return hypotf(dx, dy);
}

CGPoint LineGetMidPoint(CGPoint p1, CGPoint p2) {
	return CGPointMake((p1.x + p2.x) * 0.5f,
                       (p1.y + p2.y) * 0.5f);
}

CGPoint LineGetPointAtParameter(CGPoint p1, CGPoint p2, double u) {
    if (u <= 0.0) {
        return p1;
    }
    if (u >= 1.0) {
        return p2;
    }
    if (u == 0.5) {
        return CGPointMake((p1.x + p2.x) * 0.5f,
                           (p1.y + p2.y) * 0.5f);
    }
    return CGPointMake(p1.x + (p2.x - p1.x) * u,
                       p1.y + (p2.y - p1.y) * u);
}

 
CGPoint LineGetPointAtMid(CGPoint p1, CGPoint p2){
    return LineGetPointAtParameter(p1, p2, 0.5);
}

CGPoint GetTwoLineIntersection(CGPoint p1, CGPoint p2,CGPoint p3, CGPoint p4){
    line line1;
    line line2;
    
    //line1
    line1.point1.x = p1.x;
    line1.point1.y = p1.y;
    line1.point2.x = p2.x;
    line1.point2.y = p2.y;
    
    //line2
    line2.point1.x = p3.x;
    line2.point1.y = p3.y;
    line2.point2.x = p4.x;
    line2.point2.y = p4.y;
    
    CGPoint CrossP;
    //y = a * x + b;
    int a1 = (line1.point1.y - line1.point2.y) / (line1.point1.x - line1.point2.x);
    int b1 = line1.point1.y - a1 * (line1.point1.x);
    
    int a2 = (line2.point1.y - line2.point2.y) / (line2.point1.x - line2.point2.x);
    int b2 = line2.point1.y - a1 * (line2.point1.x);
    
    CrossP.x = (b1 - b2) / (a2 - a1);
    CrossP.y = a1 * CrossP.x + b1;
    
    if (IsPointOnSegment(CrossP, p1, p2)) {
        return CrossP;
    }
    return CGPointZero;
}

CGPoint rotatePoint(CGPoint point, CGPoint anchorPoint, CGFloat angle){
    CGFloat x1 = point.x;
    CGFloat y1 = point.y;
    CGFloat x2 = anchorPoint.x;
    CGFloat y2 = anchorPoint.y;
    
    CGFloat x=(x1-x2)*cos(angle)-(y1-y2)*sin(angle)+x2;
    CGFloat y=(y1-y2)*cos(angle)+(x1-x2)*sin(angle)+y2;
    return CGPointMake(x, y);
}


