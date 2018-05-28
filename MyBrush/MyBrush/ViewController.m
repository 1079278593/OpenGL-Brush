//
//  ViewController.m
//  MyBrush
//
//  Created by 小明 on 2018/5/15.
//  Copyright © 2018年 laihua. All rights reserved.
//

#import "ViewController.h"
#import "PaintingView.h"
#define KMainScreenHeight [UIScreen mainScreen].bounds.size.height
#define KMainScreenWidth [UIScreen mainScreen].bounds.size.width
#define RGBA(r, g, b, a) [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a]

@interface ViewController ()

@property (nonatomic, strong) PaintingView *paintingView;
@property (nonatomic, strong) UIButton *eraseButton;
@property (nonatomic, strong) UIButton *snowButton;
@property (nonatomic, strong) UIButton *circleButton;
@property (nonatomic, strong) UIButton *otherButton;

@property (nonatomic, strong) UISwitch *fingerSwitch;
@property (nonatomic, strong) UISlider *strokeWidthSlider;
@property (nonatomic, strong) UISlider *strokeAlphaSlider;
@property (nonatomic, strong) UISlider *strokeStepSlider;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.paintingView = [[PaintingView alloc]init];
    self.paintingView.frame = self.view.frame;
    [self.view addSubview:self.paintingView];
    
    self.fingerSwitch.frame = CGRectMake(0, 20, 40, 40);
    
    self.eraseButton.frame = CGRectMake(60, 10, 80, 50);
    self.snowButton.frame = CGRectMake(120, 10, 80, 50);
    self.circleButton.frame = CGRectMake(180, 10, 80, 50);
    self.otherButton.frame = CGRectMake(240, 10, 80, 50);
//    self.eraseButton.center = CGPointMake(self.view.center.x, 35);
    
    
    self.strokeStepSlider.frame = CGRectMake(10, KMainScreenHeight - 40, KMainScreenWidth-20, 40);//布局：最下面
    self.strokeWidthSlider.frame = CGRectMake(10, CGRectGetMinY(self.strokeStepSlider.frame) - 40, KMainScreenWidth-20, 40);
    self.strokeAlphaSlider.frame = CGRectMake(10, CGRectGetMinY(self.strokeWidthSlider.frame) - 40, KMainScreenWidth-20, 40);
    
    UILabel *title = [[UILabel alloc]init];
    title.text = @"下面三个slider分别设置：alpha、width、step";
    title.frame = CGRectMake(10, CGRectGetMinY(self.strokeAlphaSlider.frame) - 40, KMainScreenWidth-20, 20);
    [self.view addSubview:title];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark - Event
- (void)eraseEvent:(UIButton *)button {
    [self.paintingView cleanup];
}
- (void)snowEvent:(UIButton *)button {
    self.paintingView.strokeImageName = @"snow.png";
}
- (void)circleEvent:(UIButton *)button {
    self.paintingView.strokeImageName = @"circle.png";
}
- (void)otherEvent:(UIButton *)button {
    self.paintingView.strokeImageName = @"closelyCircle.png";
}
#pragma mark switch event
- (void)fingerSwitchChange:(UISwitch *)switchs {
    self.paintingView.openFingerStroke = switchs.on;
}

#pragma mark slider event
- (void)strokeWidthChanged:(UISlider *)slider {
    self.paintingView.strokeWidth = slider.value * 200;
}
- (void)strokeStepChanged:(UISlider *)slider {
    self.paintingView.strokeStep = slider.value * 200;
}
- (void)strokeAlphaChanged:(UISlider *)slider {
    NSLog(@"%f",slider.value);
    self.paintingView.strokeAlpha = 0.1 + slider.value;
}

#pragma mark - Getter And Setter
- (UIButton *)eraseButton {
    if (_eraseButton == nil) {
        _eraseButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_eraseButton setTitle:@"清屏" forState:UIControlStateNormal];
        [_eraseButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [_eraseButton addTarget:self action:@selector(eraseEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_eraseButton];
    }
    return _eraseButton;
}

- (UIButton *)snowButton {
    if (_snowButton == nil) {
        _snowButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_snowButton setImage:[UIImage imageNamed:@"snow.png"] forState:UIControlStateNormal];
        [_snowButton addTarget:self action:@selector(snowEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_snowButton];
    }
    return _snowButton;
}

- (UIButton *)circleButton {
    if (_circleButton == nil) {
        _circleButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_circleButton setImage:[UIImage imageNamed:@"circle.png"] forState:UIControlStateNormal];
        [_circleButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [_circleButton addTarget:self action:@selector(circleEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_circleButton];
    }
    return _circleButton;
}

- (UIButton *)otherButton {
    if (_otherButton == nil) {
        _otherButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_otherButton setTitle:@"其它" forState:UIControlStateNormal];
        [_otherButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [_otherButton addTarget:self action:@selector(otherEvent:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_otherButton];
    }
    return _otherButton;
}

- (UISwitch *)fingerSwitch {
    if (_fingerSwitch == nil) {
        _fingerSwitch = [[UISwitch alloc]init];
        [_fingerSwitch addTarget:self action:@selector(fingerSwitchChange:) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:_fingerSwitch];
    }
    return _fingerSwitch;
}

- (UISlider *)strokeWidthSlider {
    
    if (_strokeWidthSlider == nil) {
        
        _strokeWidthSlider = [[UISlider alloc]init];
        _strokeWidthSlider.backgroundColor = [UIColor clearColor];
        _strokeWidthSlider.enabled = !NO;//禁止滑动
        _strokeWidthSlider.value = 0.0;
        _strokeWidthSlider.minimumValue=0.0;
        _strokeWidthSlider.maximumValue=1.0;
        
        [_strokeWidthSlider setMinimumTrackImage:nil forState:UIControlStateNormal];
        [_strokeWidthSlider setMaximumTrackImage:nil forState:UIControlStateNormal];
        
        //注意这里要加UIControlStateHightlighted的状态，否则当拖动滑块时滑块将变成原生的控件
        [_strokeWidthSlider setThumbImage:[UIImage imageNamed:@"sliderBtn"] forState:UIControlStateHighlighted];
        [_strokeWidthSlider setThumbImage:[UIImage imageNamed:@"sliderBtn"] forState:UIControlStateNormal];
        
        //滑块拖动时的事件
        [_strokeWidthSlider addTarget:self action:@selector(strokeWidthChanged:) forControlEvents:UIControlEventValueChanged];
        
        [self.view addSubview:_strokeWidthSlider];
    }
    
    return _strokeWidthSlider;
}

- (UISlider *)strokeStepSlider {
    
    if (_strokeStepSlider == nil) {
        
        _strokeStepSlider = [[UISlider alloc]init];
        _strokeStepSlider.backgroundColor = [UIColor clearColor];
        _strokeStepSlider.enabled = !NO;//禁止滑动
        _strokeStepSlider.value = 0.0;
        _strokeStepSlider.minimumValue=0.0;
        _strokeStepSlider.maximumValue=1.0;
        
        [_strokeStepSlider setMinimumTrackImage:nil forState:UIControlStateNormal];
        [_strokeStepSlider setMaximumTrackImage:nil forState:UIControlStateNormal];
        
        //注意这里要加UIControlStateHightlighted的状态，否则当拖动滑块时滑块将变成原生的控件
        [_strokeStepSlider setThumbImage:[UIImage imageNamed:@"sliderBtn"] forState:UIControlStateHighlighted];
        [_strokeStepSlider setThumbImage:[UIImage imageNamed:@"sliderBtn"] forState:UIControlStateNormal];
        
        //滑块拖动时的事件
        [_strokeStepSlider addTarget:self action:@selector(strokeStepChanged:) forControlEvents:UIControlEventValueChanged];
       
        [self.view addSubview:_strokeStepSlider];
    }
    
    return _strokeStepSlider;
}

- (UISlider *)strokeAlphaSlider {
    
    if (_strokeAlphaSlider == nil) {
        
        _strokeAlphaSlider = [[UISlider alloc]init];
        _strokeAlphaSlider.backgroundColor = [UIColor clearColor];
        _strokeAlphaSlider.enabled = !NO;//禁止滑动
        _strokeAlphaSlider.value = 0.0;
        _strokeAlphaSlider.minimumValue=0.0;
        _strokeAlphaSlider.maximumValue=1.0;
        
        [_strokeAlphaSlider setMinimumTrackImage:nil forState:UIControlStateNormal];
        [_strokeAlphaSlider setMaximumTrackImage:nil forState:UIControlStateNormal];
        
        //注意这里要加UIControlStateHightlighted的状态，否则当拖动滑块时滑块将变成原生的控件
        [_strokeAlphaSlider setThumbImage:[UIImage imageNamed:@"sliderBtn"] forState:UIControlStateHighlighted];
        [_strokeAlphaSlider setThumbImage:[UIImage imageNamed:@"sliderBtn"] forState:UIControlStateNormal];
        
        //滑块拖动时的事件
        [_strokeAlphaSlider addTarget:self action:@selector(strokeAlphaChanged:) forControlEvents:UIControlEventValueChanged];
        
        [self.view addSubview:_strokeAlphaSlider];
    }
    
    return _strokeAlphaSlider;
}

@end
