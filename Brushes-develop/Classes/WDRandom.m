//
//  WDRandom.m
//  Brushes
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
//  Copyright (c) 2012-2013 Steve Sprang
//

#import "WDRandom.h"

//
// From http://en.wikipedia.org/wiki/Mersenne_Twister
//

@implementation WDRandom {
    UInt32 MT_[624];
    int ix_;
}

- (id) initWithSeed:(UInt32)seed
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    /**
     ^运算符：异或运算。
     如果a、b两个值不相同，则异或结果为1。如果a、b两个值相同，异或结果为0。
     比如：
     a=9（二进制1001），b=12（二进制1100），那么 a ^ b 的结果是5（二进制0101）
     
     
     >>或者<<：位移运算。
     移位时，移出的位数全部丢弃，移出的空位补入的数与左移还是右移有关。如果是左移，则规定补入的数全部是0；如果是右移，还与被移位的数据是否带符号有关。若是不带符号数，则补入的数全部为0；若是带符号数，则补入的数全部等于原数的最左端位上的原数(即原符号位)。
     例如：
     设无符号短整型变量a为0111(对应二进制数为0000000100010001),
     则：a<<3 结果为0888(对应二进制数为0000100010001000)，a不变（即运算式本身为一个值，但不改变被操作对象值）
     a>>4 结果为006　(对应二进制数为0000000000010001)，a不变
     又如，设短整型变量a为-4(对应二进制数为1111111111111100),
     则：a<<3 结果为-32(对应二进制数为1111111111100000)，a不变
     a>>4 结果为-1(对应二进制数为1111111111111111)，a不变
     */
    MT_[0] = seed;
    for (int i = 1; i < 624; i++) {
        MT_[i] = (1812433253 * (MT_[i-1] ^ (MT_[i-1] >> 30)) + i);
    }
    
    ix_ = 0;
    
    return self;
}

- (void) generateNumbers
{
    for (int i = 0; i < 624; i++) { 
        UInt32 y = (MT_[i] & 0x80000000) + (MT_[(i+1) % 624] & (0x7FFFFFFF));
        MT_[i] = MT_[(i + 397) % 624] ^ (y >> 1);
        
        if (y % 2 == 1) {
            MT_[i] = MT_[i] ^ 2567483615;
        }
    }
}

- (UInt32) nextInt
{
    if (ix_ == 0) {
        [self generateNumbers];
    }
    
    UInt32 y = MT_[ix_];
    
    y = y ^ (y >> 11);
    y = y ^ ((y << 7) & 2636928640);
    y = y ^ ((y << 15) & 4022730752);
    y = y ^ (y >> 18);
    
    ix_ = (ix_ + 1) % 624;
    return y;
}

- (float) nextFloat
{
    float r = [self nextInt] % 100000;
    return (r / 99999.0f);
}

- (float) nextFloatMin:(float)min max:(float)max
{
    return min + [self nextFloat] * (max - min);
}

- (float) nextSign
{
    return 1.0 - ([self nextInt] % 2) * 2;
}

@end

