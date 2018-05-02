//
//  WDStampGenerator.m
//  GLPaint
//
//  Created by 小明 on 2018/5/2.
//

#import "WDStampGenerator.h"
#import <Accelerate/Accelerate.h>
#import "WDRandom.h"

@implementation WDStampGenerator
+ (UIImage *)stamp {
    return [[self class]generateStamp:CGSizeMake(512, 512) scale:1 blurRadius:0];
}

#pragma mark - 生成‘图章’
+ (UIImage *) generateStamp:(CGSize)size scale:(CGFloat)scale blurRadius:(UInt8)blurRadius {
    
    size_t  width = size.width;
    size_t  height = size.height;
    size_t  rowByteSize = width;
    CGRect  bounds = CGRectMake(0, 0, width, height);
    void    *data = calloc(sizeof(UInt8), width * height);
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(data, width, height, 8, rowByteSize, colorspace, kCGImageAlphaNone);
    CGColorSpaceRelease(colorspace);
    
    // make our bitmap context the current context
    UIGraphicsPushContext(context);
    
    // fill black
    CGContextSetGrayFillColor(context, 0.0f, 1.0f);
    CGContextFillRect(context, bounds);
    
    unsigned int seed = 439945596;
    //这个很重要
    WDRandom *random = [[WDRandom alloc] initWithSeed:seed];
    
    if (scale != 1.0) {
        CGContextSaveGState(context);
        CGContextScaleCTM(context, scale, scale);
        [self renderStamp:context randomizer:random];
        CGContextRestoreGState(context);
    } else {
        [self renderStamp:context randomizer:random];
    }
    
    if (blurRadius != 0) {
        uint32_t kernelDimension = blurRadius * 2 + 1; // must be odd
        void    *outData = calloc(sizeof(UInt8), width * height);
        size_t  rowBytes = width;
        
        vImage_Buffer src = { data, height, width, rowBytes };
        vImage_Buffer dest = { outData, height, width, rowBytes };
        vImage_Error err;
        
        err = vImageTentConvolve_Planar8(&src, &dest, NULL, 0, 0, kernelDimension, kernelDimension, 0, kvImageBackgroundColorFill);
        
        if (err != kvImageNoError) {
            // NSLog something
        }
        
        // put the data back
        memcpy(data, outData, width * height);
        free(outData);
    }
    
    // get image
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *result = [[UIImage alloc] initWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    UIGraphicsPopContext();
    CGContextRelease(context);
    free(data);
    
    return result;
}

+ (void) renderStamp:(CGContextRef)ctx randomizer:(WDRandom *)randomizer
{
    size_t  width = 512;
    
    int steps = 20;
    float dim = (float) width / steps;
    CGRect box = CGRectMake(0, 0, dim, dim);
    
    for (float y = 0; y < steps; y++) {
        for (float x = 0; x < steps; x++) {
            box.origin = CGPointMake(x * dim, y * dim);
            float inset = [randomizer nextFloat] * 0.25 * dim;
            
            CGContextSetGrayFillColor(ctx, [randomizer nextFloat], 1.0f);
            CGContextFillEllipseInRect(ctx, CGRectInset(box, inset, inset));
        }
    }
}

@end
