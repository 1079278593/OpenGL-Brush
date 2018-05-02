//
//  SVGPathGet.m
//  GLPaint
//
//  Created by 小明 on 2018/1/24.
//

#import "SVGPathGet.h"
#import <SVGKit/SVGKit.h>
@interface SVGPathGet (){
    SVGKImage *svgImage;
    SVGKLayeredImageView *svgView;
}

@property (nonatomic, assign) CGMutablePathRef path;

//@property (strong ,nonatomic)CAShapeLayer *shapeLayer;
//@property (strong ,nonatomic)UIImageView *handImageView;
//@property (strong ,nonatomic)UIView *resultView;
//@property (strong ,nonatomic)UIButton *button;

@end

@implementation SVGPathGet

#pragma mark - Public Method
- (CGMutablePathRef)getPathWithSVGImageName:(NSString *)name {
    
    name = @"shower";
    svgImage = [SVGKImage imageNamed:name];
    
    return [self pathFromDocument:svgImage.DOMDocument];
}

#pragma mark - 从SVGDocument获取cgPath
-(CGMutablePathRef)pathFromDocument:(SVGDocument *)svgDocument{
    
    self.path = CGPathCreateMutable();
    
    SVGSVGElement *svgsvgElement = svgDocument.rootElement;
    NodeList *nodelist = svgsvgElement.childNodes;
    NSArray *GArray = nodelist.internalArray;
    NSLog(@"%lu",(unsigned long)GArray.count);
    [self pathFromNode:GArray];
    
    return self.path;
}

-(void)pathFromNode:(NSArray *)childNodes{
    
    for (id obj in childNodes) {
        if ([obj isKindOfClass:[SVGElement class]]) {
            if ([obj isKindOfClass:[BaseClassForAllSVGBasicShapes class]]) {
                BaseClassForAllSVGBasicShapes *shapePath = obj;
                CGPathAddPath(self.path, &CGAffineTransformIdentity, shapePath.pathForShapeInRelativeCoords);
            }else{
                SVGGElement *gElement = obj;
                [self pathFromNode:gElement.childNodes.internalArray];
            }
        }
    }
    
}

@end
