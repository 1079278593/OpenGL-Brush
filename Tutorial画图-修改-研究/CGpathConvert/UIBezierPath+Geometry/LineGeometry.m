//
//  LineGeometry.m
//
//  Created by Stephan Michels on 21.07.12.
//
//

#import "LineGeometry.h"

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
