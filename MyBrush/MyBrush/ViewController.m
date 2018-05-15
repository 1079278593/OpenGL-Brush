//
//  ViewController.m
//  MyBrush
//
//  Created by 小明 on 2018/5/15.
//  Copyright © 2018年 laihua. All rights reserved.
//

#import "ViewController.h"
#import "PaintingView.h"

@interface ViewController ()

@property (nonatomic, strong) PaintingView *paintingView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.paintingView = [[PaintingView alloc]init];
    self.paintingView.frame = self.view.frame;
    [self.view addSubview:self.paintingView];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
