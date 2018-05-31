//  LineGeometry.m
//  Created by Sumbo Tang on 22.12.17.
//
//

#import "QuadCurveGeometry.h"
#import "LineGeometry.h"

CGFloat const quad_distance_tolerance = 0.5f;

CGFloat QuadCurveGetLength(CGPoint p1, CGPoint p2, CGPoint p3){
    // Try to approximate the full cubic curve by a single straight line
    if (QuadCurveIsLinear(p1, p2, p3)) {
        return LineGetLength(p1, p3);
    }
    
    // Calculate all the mid-points of the line segments
    CGPoint p12   = LineGetMidPoint(p1, p2);
    CGPoint p23   = LineGetMidPoint(p2, p3);
    CGPoint p123  = LineGetMidPoint(p12, p23);
    
    // Continue subdivision
    return QuadCurveGetLength(p1, p12, p123) +
    QuadCurveGetLength(p123, p23, p3);
}

BOOL QuadCurveIsLinear(CGPoint p1, CGPoint p2, CGPoint p3){
    CGFloat dx = p3.x - p1.x;
    CGFloat dy = p3.y - p1.y;
    
    CGFloat d = fabs(((p2.x - p3.x) * dy - (p2.y - p3.y) * dx));
    
    return d * d <= quad_distance_tolerance * (dx * dx + dy * dy);
}

CGPoint QuadCurveGetPointAtParameter(CGPoint p1, CGPoint p2, CGPoint p3, double u){
    CGFloat b0 = QuadCurveTerm1(u);
    CGFloat b1 = QuadCurveTerm2(u);
    CGFloat b2 = QuadCurveTerm3(u);
    CGFloat quadX = p1.x * b0 + p2.x * b1 + p3.x * b2;
    CGFloat quadY = p1.y * b0 + p2.y * b1 + p3.y * b2;
    return CGPointMake(quadX, quadY);
}

CGFloat QuadCurveParameterForLength(CGPoint p1, CGPoint p2, CGPoint p3, CGFloat length){
    if (length <= 0) {
        return 0.0;
    }
    
    if (QuadCurveIsLinear(p1, p2, p3)) {
        double totalLength = LineGetLength(p1, p3);
        if (totalLength == 0.0f) {
            return 0.0;
        }
        return MAX(0.0, MIN(1.0, length / totalLength));
    }
    
    CGFloat totalLength = QuadCurveGetLength(p1, p2, p3);
    if (totalLength == 0.0f) {
        return 0.0;
    }
    if (length >= totalLength) {
        return 1.0;
    }
    
    CGPoint p12   = LineGetMidPoint(p1, p2);
    CGPoint p23   = LineGetMidPoint(p2, p3);
    CGPoint p1223 = LineGetMidPoint(p12, p23);
    
    CGFloat halfLength = QuadCurveGetLength(p1, p12, p1223);
    if (halfLength == length) {
        return 0.5;
    } else if (length < halfLength) {
        return QuadCurveParameterForLength(p1, p12, p1223, length) * 0.5;
    } else {
        return QuadCurveParameterForLength(p1223, p23, p3, length - halfLength) * 0.5 + 0.5;
    }
}

void QuadCurveGetSubdivisionAtParameter(CGPoint p1, CGPoint p2, CGPoint p3, double u, BOOL first, CGPoint *sdp1, CGPoint *sdp2, CGPoint *sdp3){
    if (u <= 0.0) {
        if (first) {
            *sdp1 = p1;
            *sdp2 = p1;
            *sdp3 = p1;
        } else {
            *sdp1 = p1;
            *sdp2 = p2;
            *sdp3 = p3;
        }
        return;
    }
    if (u >= 1.0) {
        if (first) {
            *sdp1 = p1;
            *sdp2 = p2;
            *sdp3 = p3;
        } else {
            *sdp1 = p3;
            *sdp2 = p3;
            *sdp3 = p3;
        }
    }

    // calculate parameterized point on the lines
    CGPoint p12   = LineGetPointAtParameter(p1, p2, u);
    CGPoint p23   = LineGetPointAtParameter(p2, p3, u);
    CGPoint p1223  = LineGetPointAtParameter(p12, p23, u);

    if (first) {
        *sdp1 = p1;
        *sdp2 = p12;
        *sdp3 = p1223;
    } else {
        *sdp1 = p1223;
        *sdp2 = p23;
        *sdp3 = p3;
    }
}

CGFloat QuadCurveTerm1(CGFloat u){
    CGFloat tmp = 1.0f - u;
    return tmp * tmp;
}

CGFloat QuadCurveTerm2(CGFloat u){
    CGFloat tmp = 1.0f - u;
    return 2.0 * tmp * u;
}

CGFloat QuadCurveTerm3(CGFloat u){
    return u * u;
}
