//  CurveGeometry.m
//  Created by Stephan Michels on 19.07.12.
//
//

#import "CuvbicCurveGeometry.h"
#import "LineGeometry.h"

// see http://www.antigrain.com/research/adaptive_bezier/index.html

CGFloat const m_distance_tolerance = 0.5f;

CGFloat CubicCurveLength(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4) {
	// Try to approximate the full cubic curve by a single straight line
	if (CubicCurveIsLinear(p1, p2, p3, p4)) {
		return LineGetLength(p1, p4);
    }
    
    // Calculate all the mid-points of the line segments
    CGPoint p12   = LineGetMidPoint(p1, p2);
    CGPoint p23   = LineGetMidPoint(p2, p3);
    CGPoint p34   = LineGetMidPoint(p3, p4);
    CGPoint p123  = LineGetMidPoint(p12, p23);
    CGPoint p234  = LineGetMidPoint(p23, p34);
    CGPoint p1234 = LineGetMidPoint(p123, p234);
    
    // Continue subdivision
    return CubicCurveLength(p1, p12, p123, p1234) +
           CubicCurveLength(p1234, p234, p34, p4);
}

BOOL CubicCurveIsLinear(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4) {
    
	CGFloat dx = p4.x - p1.x;
	CGFloat dy = p4.y - p1.y;
	
	CGFloat d2 = fabs(((p2.x - p4.x) * dy - (p2.y - p4.y) * dx));
	CGFloat d3 = fabs(((p3.x - p4.x) * dy - (p3.y - p4.y) * dx));
	
	return (d2 + d3) * (d2 + d3) <= m_distance_tolerance * (dx * dx + dy * dy);
}

//递归获取指定长度处的参数 u
CGFloat CubicCurveParameterForLength(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4, CGFloat length) {
    if (length <= 0) {
        return 0.0;
    }
    
    if (CubicCurveIsLinear(p1, p2, p3, p4)) {
        double totalLength = LineGetLength(p1, p4);
        if (totalLength == 0.0f) {
            return 0.0;
        }
        return MAX(0.0, MIN(1.0, length / totalLength));
    }
    
    CGFloat totalLength = CubicCurveLength(p1, p2, p3, p4);
    if (totalLength == 0.0f) {
        return 0.0;
    }
    if (length >= totalLength) {
        return 1.0;
    }
    
    CGPoint p12   = LineGetMidPoint(p1, p2);
    CGPoint p23   = LineGetMidPoint(p2, p3);
    CGPoint p34   = LineGetMidPoint(p3, p4);
    CGPoint p123  = LineGetMidPoint(p12, p23);
    CGPoint p234  = LineGetMidPoint(p23, p34);
    CGPoint p1234 = LineGetMidPoint(p123, p234);
    
    CGFloat halfLength = CubicCurveLength(p1, p12, p123, p1234);
    if (halfLength == length) {
        return 0.5;
    } else if (length < halfLength) {
        return CubicCurveParameterForLength(p1, p12, p123, p1234, length) * 0.5;
    } else {
        return CubicCurveParameterForLength(p1234, p234, p34, p4, length - halfLength) * 0.5 + 0.5;
    }
}

CGPoint CubicCurveGetPointAtParameter(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4, double u) {
    if (u <= 0.0) {
        return p1;
    }
    if (u >= 1.0) {
        return p4;
    }
    CGFloat b0 = CubicCurveTerm1(u);
    CGFloat b1 = CubicCurveTerm2(u);
    CGFloat b2 = CubicCurveTerm3(u);
    CGFloat b3 = CubicCurveTerm4(u);
    
    CGPoint point;
    point.x = p1.x * b0 + p2.x * b1 + p3.x * b2 + p4.x * b3;
    point.y = p1.y * b0 + p2.y * b1 + p3.y * b2 + p4.y * b3;
    return point;
}

void CubicCurveGetSubdivisionAtParameter(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4, double u, BOOL first, CGPoint *sdp1, CGPoint *sdp2, CGPoint *sdp3, CGPoint *sdp4) {
    if (u <= 0.0) {
        if (first) {
            *sdp1 = p1;
            *sdp2 = p1;
            *sdp3 = p1;
            *sdp4 = p1;
        } else {
            *sdp1 = p1;
            *sdp2 = p2;
            *sdp3 = p3;
            *sdp4 = p4;
        }
        return;
    }
    if (u >= 1.0) {
        if (first) {
            *sdp1 = p1;
            *sdp2 = p2;
            *sdp3 = p3;
            *sdp4 = p4;
        } else {
            *sdp1 = p4;
            *sdp2 = p4;
            *sdp3 = p4;
            *sdp4 = p4;
        }
    }
    
    // calculate parameterized point on the lines
    CGPoint p12   = LineGetPointAtParameter(p1, p2, u);
    CGPoint p23   = LineGetPointAtParameter(p2, p3, u);
    CGPoint p34   = LineGetPointAtParameter(p3, p4, u);
    CGPoint p123  = LineGetPointAtParameter(p12, p23, u);
    CGPoint p234  = LineGetPointAtParameter(p23, p34, u);
    CGPoint p1234 = LineGetPointAtParameter(p123, p234, u);
    
    if (first) {
        *sdp1 = p1;
        *sdp2 = p12;
        *sdp3 = p123;
        *sdp4 = p1234;
    } else {
        *sdp1 = p1234;
        *sdp2 = p234;
        *sdp3 = p34;
        *sdp4 = p4;
    }
}

// Bezier multipliers
CGFloat CubicCurveTerm1(CGFloat u) {
    CGFloat tmp = 1.0f - u;
    return (tmp * tmp * tmp);
}

CGFloat CubicCurveTerm2(CGFloat u) {
    CGFloat tmp = 1.0f - u;
    return (3.0f * u * (tmp * tmp));
}

CGFloat CubicCurveTerm3(CGFloat u) {
    CGFloat tmp = 1.0f - u;
    return (3.0f * u * u * tmp);
}

CGFloat CubicCurveTerm4(CGFloat u) {
    return (u * u * u);
}
