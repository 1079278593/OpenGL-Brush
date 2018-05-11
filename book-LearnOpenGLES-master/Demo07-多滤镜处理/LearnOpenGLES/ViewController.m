//
//  AppDelegate.h
//  LearnOpenGLES
//
//  Created by 林伟池 on 17/1/20.
//  Copyright © 2017年 林伟池. All rights reserved.
//

#import "ViewController.h"
#import "GLContainerView.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet GLContainerView *glContainerView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.glContainerView.image = [UIImage imageNamed:@"Lena"];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action
- (IBAction)actionValueChanged:(UISlider *)sender {
    self.glContainerView.colorTempValue = sender.value;
}

- (IBAction)actionSaturationValueChanged:(UISlider *)sender {
    self.glContainerView.saturationValue = sender.value;
}

@end
