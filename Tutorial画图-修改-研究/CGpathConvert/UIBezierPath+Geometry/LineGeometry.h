//
//  LineGeometry.h
//
//  Created by Stephan Michels on 21.07.12.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

CGPoint LineGetMidPoint(CGPoint p1, CGPoint p2);
CGFloat LineGetLength(CGPoint p1, CGPoint p2);
CGPoint LineGetPointAtParameter(CGPoint p1, CGPoint p2, double u);
CGPoint LineGetPointAtMid(CGPoint p1, CGPoint p2);
