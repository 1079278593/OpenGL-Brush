//  CurveGeometry.h
//  Created by Stephan Michels on 19.07.12.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

CGFloat CubicCurveLength(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4);
BOOL CubicCurveIsLinear(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4);
CGFloat CubicCurveParameterForLength(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4, CGFloat length);
CGPoint CubicCurveGetPointAtParameter(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4, double u);
void CubicCurveGetSubdivisionAtParameter(CGPoint p1, CGPoint p2, CGPoint p3, CGPoint p4, double u, BOOL first, CGPoint *sdp1, CGPoint *sdp2, CGPoint *sdp3, CGPoint *sdp4);
CGFloat CubicCurveTerm1(CGFloat u);
CGFloat CubicCurveTerm2(CGFloat u);
CGFloat CubicCurveTerm3(CGFloat u);
CGFloat CubicCurveTerm4(CGFloat u);
