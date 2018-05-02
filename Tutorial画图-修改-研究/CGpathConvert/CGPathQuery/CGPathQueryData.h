//
//  CGPathQueryData.h
//  Thimble
//
//  Created by Vivek Gani on 8/30/16.
//
//

#import <Foundation/Foundation.h>

@interface CGPathQueryData : NSObject

@property (strong, nonatomic) NSMutableArray<NSValue*> *queryData;
@property (assign, nonatomic) CGFloat delta;
@property (assign, nonatomic) CGFloat zeroToOneCompletionStart;
@property (assign, nonatomic) CGFloat zeroToOneCompletionEnd;

@end
