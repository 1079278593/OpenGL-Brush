//
//  LYGLViewController.m
//  LearnOpenGLES
//
//  Created by 林伟池 on 16/3/16.
//  Copyright © 2016年 林伟池. All rights reserved.
//

#import "LYGLViewController.h"
#import "LearnView.h"

@interface LYGLViewController ()
@property (nonatomic, strong) LearnView     *myView;
@property (nonatomic, strong) CADisplayLink *mDisplayLink;
@end

@implementation LYGLViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.myView = (LearnView *)self.view;
    [self.myView customInit];
    [self.myView update];
    
    self.mDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(update)];
    [self.mDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [self.mDisplayLink setPaused:NO];
}

- (void)update {
    [self.myView update];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
