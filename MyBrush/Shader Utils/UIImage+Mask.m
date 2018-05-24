//
//  UIImage+Mask.m
//  MyBrush
//
//  Created by 小明 on 2018/5/24.
//  Copyright © 2018年 laihua. All rights reserved.
//

#import "UIImage+Mask.h"
#import "WDUtilities.h"

#define Mask8(x) ( (x) & 0xFF )
#define R(x) ( Mask8(x) )
#define G(x) ( Mask8(x >> 8 ) )
#define B(x) ( Mask8(x >> 16) )
#define A(x) ( Mask8(x >> 24) )
#define RGBAMake(r, g, b, a) ( Mask8(r) | Mask8(g) << 8 | Mask8(b) << 16 | Mask8(a) << 24 )

@implementation UIImage (Mask)

+ (UIImage *)circleMaskWithSize:(NSUInteger)sideLength {
    
    CGImageRef imageRef = [UIImage imageNamed:@""].CGImage;
    
    NSUInteger inputWidth = sideLength;
    NSUInteger inputHeight = sideLength;
    NSUInteger bytesPerPixel = 4;
    NSUInteger bitsPerComponent = 8;
    NSUInteger bytesPerRow = bytesPerPixel * inputHeight;
    UInt32 * inputPixels = (UInt32 *)calloc(inputHeight*inputWidth, sizeof(UInt32));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(inputPixels, inputHeight, inputWidth,
                                                    bitsPerComponent, bytesPerRow, colorSpace,
                                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, inputHeight, inputWidth),imageRef);
    
    CGPoint center = CGPointMake(inputWidth/2.0, inputWidth/2.0);
    
    for (NSUInteger j = 0; j < inputHeight; j++) {
        for (NSUInteger i = 0; i < inputWidth; i++) {
            
            UInt32 * inputPixel = inputPixels + j * inputWidth + i ;
            
            // Blend the ghost with 50% alpha
            UInt32 newR = 255;
            UInt32 newG = 255;
            UInt32 newB = 255;
            UInt32 newA = 255;
            CGFloat distance = WDDistance(CGPointMake(i, j), center);
            if (distance >= (inputWidth/2.0)) {
                newR = 0;
                newG = 0;
                newB = 0;
                newA = 0;
            }
            
            *inputPixel = RGBAMake(newR, newG, newB, newA);
            
        }
    }
    
    // . Create a new UIImage
    CGImageRef newCGImage = CGBitmapContextCreateImage(context);
    UIImage * processedImage = [UIImage imageWithCGImage:newCGImage];
    
    // . Cleanup!
    CGImageRelease(newCGImage);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    free(inputPixels);
    
    return processedImage;

}

@end
