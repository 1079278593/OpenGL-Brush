#import "UIBezierPath+Geometry.h"
#import "LineGeometry.h"
#import "QuadCurveGeometry.h"
#import "CuvbicCurveGeometry.h"

typedef struct BezierSubpath {
    CGPoint startPoint;
    CGPoint controlPoint1;
    CGPoint controlPoint2;
    CGPoint endPoint;
    CGFloat length;
    CGPathElementType type;
} BezierSubpath;

typedef void(^BezierSubpathEnumerator)(const CGPathElement *element);

static void bezierSubpathFunction(void *info, CGPathElement const *element) {
	BezierSubpathEnumerator block = (__bridge BezierSubpathEnumerator)info;
	block(element);
}

@implementation UIBezierPath (Length)
#pragma mark - Internal
- (void)enumerateSubpaths:(BezierSubpathEnumerator)enumeratorBlock{
	CGPathApply(self.CGPath, (__bridge void *)enumeratorBlock, bezierSubpathFunction);
}

- (NSUInteger)countSubpaths{
	__block NSUInteger count = 0;
	[self enumerateSubpaths:^(const CGPathElement *element) {
        count++;
	}];
	return count;
}

- (void)extractSubpaths:(BezierSubpath*)subpathArray{
	__block CGPoint currentPoint = CGPointZero;
	__block NSUInteger i = 0;
    __block CGPoint lineStartPoint = CGPointZero;
    __block CGPoint endPoint = CGPointZero;
	[self enumerateSubpaths:^(const CGPathElement *element) {
		
		CGPathElementType type = element->type;
		CGPoint *points = element->points;
		
		CGFloat subLength = 0.0f;

		BezierSubpath subpath;
		subpath.type = type;
		subpath.startPoint = currentPoint;
		
		/*
		 *  All paths, no matter how complex, are created through a combination of these path elements.
		 */
		switch (type) {
			case kCGPathElementMoveToPoint:{
				endPoint = points[0];
                lineStartPoint = endPoint;
            }break;
                
            case kCGPathElementAddLineToPoint:{
				
				endPoint = points[0];
				subLength = LineGetLength(currentPoint, endPoint);
            }break;
                
            case kCGPathElementAddQuadCurveToPoint:{
				endPoint = points[1];
				CGPoint controlPoint = points[0];
				subLength = QuadCurveGetLength(currentPoint, controlPoint, endPoint);
				subpath.controlPoint1 = controlPoint;
            }break;
                
            case kCGPathElementAddCurveToPoint:{
				endPoint = points[2];
				CGPoint controlPoint1 = points[0];
				CGPoint controlPoint2 = points[1];
				subLength = CubicCurveLength(currentPoint, controlPoint1, controlPoint2, endPoint);
				subpath.controlPoint1 = controlPoint1;
				subpath.controlPoint2 = controlPoint2;
            }break;
                
            case kCGPathElementCloseSubpath:{
                subLength = LineGetLength(lineStartPoint, endPoint);
                subpath.startPoint = endPoint;
                endPoint = lineStartPoint;
            }break;
			default:
				break;
		}
		
		subpath.length = subLength;
		subpath.endPoint = endPoint;
		
        subpathArray[i] = subpath;
        i++;
		currentPoint = endPoint;
	}];
	if (i == 0) {
		subpathArray[0].length = 0.0f;
		subpathArray[0].endPoint = currentPoint;
	}
}

- (CGPoint)pointAtPercent:(CGFloat)t ofSubpath:(BezierSubpath)subpath {
	
	CGPoint p = CGPointZero;
	switch (subpath.type) {
		case kCGPathElementAddLineToPoint:
			p = LineGetPointAtParameter(subpath.startPoint, subpath.endPoint, t);
			break;
		case kCGPathElementAddQuadCurveToPoint:
			p = QuadCurveGetPointAtParameter(subpath.startPoint, subpath.controlPoint1, subpath.endPoint, t);
			break;
		case kCGPathElementAddCurveToPoint:
			p = CubicCurveGetPointAtParameter(subpath.startPoint, subpath.controlPoint1, subpath.controlPoint2, subpath.endPoint, t);
			break;
        case kCGPathElementCloseSubpath:
            p = LineGetPointAtParameter(subpath.startPoint, subpath.endPoint, t);
            break;
		default:
			break;
	}
	return p;
}

#pragma mark - Public API
- (UIBezierPath *)subpathFrom:(CGFloat)start to:(CGFloat)end{
    UIBezierPath *subpath = [UIBezierPath bezierPath];
    if (start >= end) {
        return subpath;
    }
    NSUInteger subpathCount = [self countSubpaths];
    BezierSubpath subpaths[subpathCount];
    [self extractSubpaths:subpaths];
    
    CGFloat totalLength = self.length;
    start = start*totalLength;
    end = end*totalLength;

    BOOL started = NO;
    CGPoint previousPoint = CGPointZero;
    for (NSUInteger elementIndex = 0; elementIndex < subpathCount; elementIndex++) {
        // if we already reached the end
        if (end < 0) {
            return subpath;
        }
        BezierSubpath linePath = subpaths[elementIndex];
        previousPoint = linePath.startPoint;
        switch (linePath.type) {
            case kCGPathElementMoveToPoint:
                started = NO;
                previousPoint = linePath.endPoint;
                break;
                
            case kCGPathElementCloseSubpath:
            case kCGPathElementAddLineToPoint:{
                CGPoint p1 = linePath.startPoint;
                CGPoint p2 = linePath.endPoint;
                if (linePath.type == kCGPathElementCloseSubpath) {
                    p1 = linePath.endPoint;
                    p2 = linePath.startPoint;
                }
                
                CGFloat lineLength = LineGetLength(p1, p2);
                
                // check if the reached the start
                if (start < lineLength) {
                    double u1 = MAX(start, 0) / lineLength;
                    double u2 = MIN(lineLength, end) / lineLength;
                    
                    CGPoint startPoint = LineGetPointAtParameter(p1, p2, u1);
                    CGPoint endPoint = LineGetPointAtParameter(p1, p2, u2);
                    
                    if (!started) {
                        started = YES;
                        [subpath moveToPoint:startPoint];
                    }
                    [subpath addLineToPoint:endPoint];
                }
                
                start -= lineLength;
                end -= lineLength;
                previousPoint = p2;

            }break;
                
            case kCGPathElementAddQuadCurveToPoint:{
                CGPoint p1 = previousPoint;
                CGPoint p2 = linePath.controlPoint1;
                CGPoint p3 = linePath.endPoint;

                CGFloat curveLength = linePath.length;

                // check if the reached the start
                if (start < curveLength) {

                    double u1 = QuadCurveParameterForLength(p1, p2, p3, start);
                    double u2 = QuadCurveParameterForLength(p1, p2, p3, end);

                    CGPoint sdp1 = p1;
                    CGPoint sdp2 = p2;
                    CGPoint sdp3 = p3;

                    // check to remove a part at the beginning of the current curve element
                    if (u1 > 0.0) {
                        QuadCurveGetSubdivisionAtParameter(sdp1, sdp2, sdp3, u1, NO, &sdp1, &sdp2, &sdp3);
                        [subpath moveToPoint:sdp1];
                        started = YES;
                    }
                    if (!started) {
                        [subpath moveToPoint:sdp1];
                        started = YES;
                    }

                    // check to remove a part at the end of the current curve element
                    if (u2 < 1.0) {
                        QuadCurveGetSubdivisionAtParameter(sdp1, sdp2, sdp3, (u2 - u1) / (1 - u1), YES, &sdp1, &sdp2, &sdp3);
                    }
                    [subpath addQuadCurveToPoint:sdp3 controlPoint:sdp2];
                }

                start -= curveLength;
                end -= curveLength;
                previousPoint = p3;
            }break;
                
            case kCGPathElementAddCurveToPoint:{
                CGPoint p1 = previousPoint;
                CGPoint p2 = linePath.controlPoint1;
                CGPoint p3 = linePath.controlPoint2;
                CGPoint p4 = linePath.endPoint;
                
                CGFloat curveLength = linePath.length;
                
                // check if the reached the start
                if (start < curveLength) {
                    
                    double u1 = CubicCurveParameterForLength(p1, p2, p3, p4, start);
                    double u2 = CubicCurveParameterForLength(p1, p2, p3, p4, end);
                    
                    CGPoint sdp1 = p1;
                    CGPoint sdp2 = p2;
                    CGPoint sdp3 = p3;
                    CGPoint sdp4 = p4;
                    
                    // check to remove a part at the beginning of the current curve element
                    if (u1 > 0.0) {
                        CubicCurveGetSubdivisionAtParameter(sdp1, sdp2, sdp3, sdp4, u1, NO, &sdp1, &sdp2, &sdp3, &sdp4);
                        [subpath moveToPoint:sdp1];
                        started = YES;
                    }
                    if (!started) {
                        [subpath moveToPoint:sdp1];
                        started = YES;
                    }
                    
                    // check to remove a part at the end of the current curve element
                    if (u2 < 1.0) {
                        CubicCurveGetSubdivisionAtParameter(sdp1, sdp2, sdp3, sdp4, (u2 - u1) / (1 - u1), YES, &sdp1, &sdp2, &sdp3, &sdp4);
                    }
                    [subpath addCurveToPoint:sdp4 controlPoint1:sdp2 controlPoint2:sdp3];
                }
                
                start -= curveLength;
                end -= curveLength;
                previousPoint = p4;
            }break;
                
            default:
                break;
        }
        
    }
    return subpath;
}

- (CGFloat)length {
	NSUInteger subpathCount = [self countSubpaths];
	BezierSubpath subpaths[subpathCount];
	[self extractSubpaths:subpaths];
	
	CGFloat length = 0.0f;
	for (NSUInteger i = 0; i < subpathCount; i++) {
		length += subpaths[i].length;
	}
	return length;
}

- (CGPoint)pointAtPercentOfLength:(CGFloat)percent {
	
	if (percent < 0.0f) {
		percent = 0.0f;
	} else if (percent > 1.0f) {
		percent = 1.0f;
	}
	
	NSUInteger subpathCount = [self countSubpaths];
	BezierSubpath subpaths[subpathCount];
	[self extractSubpaths:subpaths];
    
	CGFloat length = 0.0f;
	for (NSUInteger i = 0; i < subpathCount; i++) {
		length += subpaths[i].length;
	}
	
    CGFloat pointLocationInPath = length * percent;
    CGFloat currentLength = 0;
    BezierSubpath subpathContainingPoint;
	for (NSUInteger i = 0; i < subpathCount; i++) {
		if (currentLength + subpaths[i].length >= pointLocationInPath) {
			subpathContainingPoint = subpaths[i];
			break;
		} else {
			currentLength += subpaths[i].length;
		}
	}
	
    CGFloat lengthInSubpath = pointLocationInPath - currentLength;
	if (subpathContainingPoint.length == 0) {
		return subpathContainingPoint.endPoint;
	} else {
		CGFloat t = lengthInSubpath / subpathContainingPoint.length;
		return [self pointAtPercent:t ofSubpath:subpathContainingPoint];
	}
}


- (void)newMaskPathFrame:(CGRect)frame{
    [self removeAllPoints];
    CGFloat margin = LINE_WIDTH * 0.5 * sqrt(2);
    CGFloat offset = margin;
    CGFloat maxOffset = CGRectGetMaxY(frame) + CGRectGetMaxX(frame) + margin;
    flag = YES;
    while (offset < maxOffset) {
        [self bound:frame offsetX:offset];
        offset += 2 * margin;
    }
}
static BOOL flag = YES;
- (void)bound:(CGRect)frame offsetX:(CGFloat)offsetX {
    CGFloat dxy = (LINE_WIDTH / 2) / sqrt(2);
    CGRect iframe = CGRectInset(frame, -dxy, -dxy);
    CGFloat A = -1;
    CGFloat B = offsetX;
    
    //左
    CGFloat x1 = iframe.origin.x;
    CGFloat y1 = A * x1 + B;
    CGPoint point1 = CGPointMake(x1, y1);
    
    //右
    CGFloat x2 = CGRectGetMaxX(iframe);
    CGFloat y2 = A * x2 + B;
    CGPoint point2 = CGPointMake(x2, y2);
    
    //上
    CGFloat y3 = iframe.origin.y;
    CGFloat x3 = (y3 - B) / A;
    CGPoint point3 = CGPointMake(x3, y3);
    
    //下
    CGFloat y4 = CGRectGetMaxY(iframe);
    CGFloat x4 = (y4 - B) / A;
    CGPoint point4 = CGPointMake(x4, y4);
    
    CGPoint point10 = CGPointZero;
    CGPoint point11 = CGPointZero;
    
    if (y1 <= CGRectGetMaxY(iframe)) {
        point10 = point1;
    } else {
        point10 = point4;
    }
    
    if (x3 <= CGRectGetMaxX(iframe)) {
        point11 = point3;
    } else {
        point11 = point2;
    }
    
    if (flag) {
        [self moveToPoint:point10];
        [self addLineToPoint:point11];
    } else {
        [self moveToPoint:point11];
        [self addLineToPoint:point10];
    }
    flag = !flag;
}
@end
