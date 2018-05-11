//
//  SimpleEditor.m
//  LearnAVFoundation
//
//  Created by 林伟池 on 16/6/28.
//  Copyright © 2016年 林伟池. All rights reserved.
//

#import "SimpleEditor.h"
#import <CoreMedia/CoreMedia.h>
#import "LYVideoCompostion.h"

@interface SimpleEditor ()


@end

@implementation SimpleEditor


- (void)buildCompositionObjectsForPlayback
{
    if ( (self.clips == nil) || [self.clips count] == 0 ) {
        self.composition = nil;
        self.videoComposition = nil;
        return;
    }
    
    CGSize videoSize = [[self.clips objectAtIndex:0] naturalSize];
    [self buildTransitionComposition];

    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:self.composition];
    videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
    videoComposition.renderSize = videoSize;
    videoComposition.customVideoCompositorClass = [LYVideoCompostion class];
    self.videoComposition = videoComposition;
    
}

- (void)buildTransitionComposition
{
    AVMutableComposition *composition = [AVMutableComposition composition];
    CMTime nextClipStartTime = kCMTimeZero;
    NSInteger i;
    NSUInteger clipsCount = [self.clips count];
    
    // 确保最后合并后的视频，变换长度不会超过最小长度的一半
    CMTime transitionDuration = self.transitionDuration;
    for (i = 0; i < clipsCount; i++ ) {
        NSValue *clipTimeRange = [self.clipTimeRanges objectAtIndex:i];
        if (clipTimeRange) {
            CMTime halfClipDuration = [clipTimeRange CMTimeRangeValue].duration;
            halfClipDuration.timescale *= 2;
            transitionDuration = CMTimeMinimum(transitionDuration, halfClipDuration);
        }
    }
    
    // Add two video tracks and two audio tracks.
    AVMutableCompositionTrack *compositionVideoTracks[2];
    AVMutableCompositionTrack *compositionAudioTracks[2];
    compositionVideoTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid]; // 添加视频轨道0
    compositionVideoTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid]; // 添加视频轨道1
    compositionAudioTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid]; // 添加音频轨道0
    compositionAudioTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid]; // 添加音频轨道1
    
    
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    for (i = 0; i < clipsCount; i++ ) {
        NSInteger alternatingIndex = i % 2; // alternating targets: 0, 1, 0, 1, ...
        AVURLAsset *asset = [self.clips objectAtIndex:i];
        NSValue *clipTimeRange = [self.clipTimeRanges objectAtIndex:i];
        CMTimeRange timeRangeInAsset;
        if (clipTimeRange) {
            timeRangeInAsset = [clipTimeRange CMTimeRangeValue];
        }
        else {
            timeRangeInAsset = CMTimeRangeMake(kCMTimeZero, [asset duration]);
        }
        
        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        NSError* error;
        [compositionVideoTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipVideoTrack atTime:nextClipStartTime error:&error];
        NSLog(@"video track %ld, insert start:%lf, length:%lf, at time:%lf", alternatingIndex, CMTimeGetSeconds(timeRangeInAsset.start), CMTimeGetSeconds(timeRangeInAsset.duration), CMTimeGetSeconds(nextClipStartTime));
        
        AVAssetTrack *clipAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
        [compositionAudioTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:nextClipStartTime error:&error];
        
        
        // 计算下一个插入点
        nextClipStartTime = CMTimeAdd(nextClipStartTime, timeRangeInAsset.duration); // 加上持续时间
        nextClipStartTime = CMTimeSubtract(nextClipStartTime, transitionDuration); // 减去变换时间，得到下一个插入点
    }
    self.composition = composition;
}

- (AVPlayerItem *)playerItem
{
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:self.composition];
    playerItem.videoComposition = self.videoComposition;
    
    return playerItem;
}

@end
