//
//  ViewController.m
//  LearnQuartz
//
//  Created by 林伟池 on 16/9/29.
//  Copyright © 2016年 林伟池. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:imageView];
    [imageView setImage:[self ImageWithColor]];
}

#define RECT_WITDH 32
#define RECT_HEIGHT 32

- (UIImage *) ImageWithColor
{
    CGRect frame = CGRectMake(0, 0, 512, 512);
    UIGraphicsBeginImageContext(frame.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    for (int i = 0; i <= CGRectGetWidth(frame); i += RECT_WITDH) {
        for (int j = 0; j <= CGRectGetHeight(frame); j += RECT_HEIGHT) {
            if ((i / RECT_WITDH + j / RECT_HEIGHT) % 2) {
                CGContextSetRGBFillColor(context, 0, 0, 0, 1);
            }
            else {
                CGContextSetRGBFillColor(context, 1, 1, 1, 1);
            }
            CGContextFillRect(context, CGRectMake(i, j, RECT_WITDH, RECT_HEIGHT));
        }
    }
    
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSData *data = UIImagePNGRepresentation(theImage);
    
    return theImage;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
