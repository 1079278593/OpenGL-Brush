//
//  PaintingView.h
//  MyBrush
//
//  Created by 小明 on 2018/5/15.
//  Copyright © 2018年 laihua. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

@interface PaintingView : UIView

- (void)cleanup;
@property (nonatomic, assign) BOOL openFingerStroke;//开启识别手指：力度(控制透明度)、范围(控制笔刷宽度)
@property (nonatomic, copy) UIColor *strokeColor;
@property (nonatomic, assign) CGFloat strokeStep;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) CGFloat strokeAlpha;

@end
