//
//  ViewController.m
//  LearnAVFoundation
//
//  Created by 林伟池 on 16/6/28.
//  Copyright © 2016年 林伟池. All rights reserved.
//

#import "ViewController.h"
#import "SimpleEditor.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>


@interface PlayerView : UIView

@property (nonatomic, retain) AVPlayer *player;

@end

@implementation PlayerView

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (AVPlayer *)player
{
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)player
{
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}

@end

static NSString* const AVCDVPlayerViewControllerStatusObservationContext	= @"AVCDVPlayerViewControllerStatusObservationContext";
static NSString* const AVCDVPlayerViewControllerRateObservationContext = @"AVCDVPlayerViewControllerRateObservationContext";
static void testContext(){};

@interface ViewController ()
{
    BOOL			_playing;
    BOOL			_scrubInFlight;
    BOOL			_seekToZeroBeforePlaying;
    float			_lastScrubSliderValue;
    float			_playRateToRestore;
    id				_timeObserver;
    
    float			_transitionDuration;
    BOOL			_transitionsEnabled;
}

@property SimpleEditor		*editor;
@property NSMutableArray		*clips;
@property NSMutableArray		*clipTimeRanges;
@property (nonatomic , strong) NSMutableArray *arrVaild;

@property AVPlayer				*player;
@property AVPlayerItem			*playerItem;

@property (nonatomic, weak) IBOutlet PlayerView				*playerView;

@property (nonatomic, weak) IBOutlet UIToolbar				*toolbar;
@property (nonatomic, weak) IBOutlet UISlider				*scrubber;
@property (nonatomic, weak) IBOutlet UIBarButtonItem		*playPauseButton;
@property (nonatomic, weak) IBOutlet UILabel				*currentTimeLabel;

- (IBAction)togglePlayPause:(id)sender;

- (IBAction)beginScrubbing:(id)sender;
- (IBAction)scrub:(id)sender;
- (IBAction)endScrubbing:(id)sender;

- (void)updatePlayPauseButton;
- (void)updateScrubber;
- (void)updateTimeLabel;

- (CMTime)playerItemDuration;

- (void)synchronizePlayerWithEditor;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.editor = [[SimpleEditor alloc] init];
    self.clips = [[NSMutableArray alloc] init];
    self.clipTimeRanges = [[NSMutableArray alloc] init];
    
    _transitionDuration = 3.0; // 默认变换时间
    _transitionsEnabled = YES;
    
    [self updateScrubber];
    [self updateTimeLabel];
    
    [self setupEditingAndPlayback];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!self.player) {
        _seekToZeroBeforePlaying = NO;
        self.player = [[AVPlayer alloc] init];
        [self.player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:(__bridge void *)(AVCDVPlayerViewControllerRateObservationContext)];
        [self.playerView setPlayer:self.player];
    }
    
    [self addTimeObserverToPlayer];
    
    
    [self.editor buildCompositionObjectsForPlayback];
    [self synchronizePlayerWithEditor];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.player pause];
    [self removeTimeObserverFromPlayer];
}

#pragma mark - Simple Editor

- (void)setupEditingAndPlayback
{
    AVURLAsset *asset3 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"abc" ofType:@"mp4"]]];
    AVURLAsset *asset2 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"qwe" ofType:@"mp4"]]];
    AVURLAsset *asset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"eer" ofType:@"mp4"]]];
    
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    NSArray *assetKeysToLoadAndTest = @[@"tracks", @"duration", @"composable"];
    
    // 加载视频
    [self loadAsset:asset1 withKeys:assetKeysToLoadAndTest usingDispatchGroup:dispatchGroup];
    [self loadAsset:asset2 withKeys:assetKeysToLoadAndTest usingDispatchGroup:dispatchGroup];
    [self loadAsset:asset3 withKeys:assetKeysToLoadAndTest usingDispatchGroup:dispatchGroup];
    
    
    // 等待就绪
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^(){
        [self synchronizeWithEditor];
    });
}

- (void)loadAsset:(AVAsset *)asset withKeys:(NSArray *)assetKeysToLoad usingDispatchGroup:(dispatch_group_t)dispatchGroup
{
    dispatch_group_enter(dispatchGroup);
    [asset loadValuesAsynchronouslyForKeys:assetKeysToLoad completionHandler:^(){
        // 测试是否成功加载
        BOOL bSuccess = YES;
        for (NSString *key in assetKeysToLoad) {
            NSError *error;
            
            if ([asset statusOfValueForKey:key error:&error] == AVKeyValueStatusFailed) {
                NSLog(@"Key value loading failed for key:%@ with error: %@", key, error);
                bSuccess = NO;
                break;
            }
        }
        if (![asset isComposable]) {
            NSLog(@"Asset is not composable");
            bSuccess = NO;
        }
        if (bSuccess && CMTimeGetSeconds(asset.duration) > 5) {
            [self.clips addObject:asset];
            [self.clipTimeRanges addObject:[NSValue valueWithCMTimeRange:CMTimeRangeMake(CMTimeMakeWithSeconds(0, 1), CMTimeMakeWithSeconds(5, 1))]];
        }
        else {
            NSLog(@"error ");
        }
        dispatch_group_leave(dispatchGroup);
    }];
}

/**
 *  开始播放
 */
- (void)synchronizePlayerWithEditor
{
    if ( self.player == nil )
        return;
    
    AVPlayerItem *playerItem = [self.editor playerItem];
    
    if (self.playerItem != playerItem) {
        if ( self.playerItem ) {
            [self.playerItem removeObserver:self forKeyPath:@"status"];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem]; // 移除监听
        }
        
        self.playerItem = playerItem;
        
        if ( self.playerItem ) {
            // 监听status属性，是否已经就绪
            [self.playerItem addObserver:self forKeyPath:@"status" options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial) context:(__bridge void *)(AVCDVPlayerViewControllerStatusObservationContext)];
            
            // 播放完成的监听
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
        }
        [self.player replaceCurrentItemWithPlayerItem:playerItem];
    }
}

- (void)synchronizeWithEditor
{
    // Clips
    [self synchronizeEditorClipsWithOurClips];
    [self synchronizeEditorClipTimeRangesWithOurClipTimeRanges];
    
    
    // Transitions
    if (_transitionsEnabled) {
        self.editor.transitionDuration = CMTimeMakeWithSeconds(_transitionDuration, 600);
    } else {
        self.editor.transitionDuration = kCMTimeInvalid;
    }
    
    [self.editor buildCompositionObjectsForPlayback];
    [self synchronizePlayerWithEditor];
    
}

- (void)synchronizeEditorClipsWithOurClips
{
    NSMutableArray *validClips = [NSMutableArray array];
    for (AVURLAsset *asset in self.clips) {
        if (![asset isKindOfClass:[NSNull class]]) {
            [validClips addObject:asset];
        }
    }
    
    self.editor.clips = validClips;
}

- (void)synchronizeEditorClipTimeRangesWithOurClipTimeRanges
{
    NSMutableArray *validClipTimeRanges = [NSMutableArray array];
    for (NSValue *timeRange in self.clipTimeRanges) {
        if (! [timeRange isKindOfClass:[NSNull class]]) {
            [validClipTimeRanges addObject:timeRange];
        }
    }
    
    self.editor.clipTimeRanges = validClipTimeRanges;
}

#pragma mark - Utilities

- (void)addTimeObserverToPlayer
{
    if (_timeObserver)
        return;
    
    if (self.player == nil)
        return;
    
    if (self.player.currentItem.status != AVPlayerItemStatusReadyToPlay)
        return;
    
    double duration = CMTimeGetSeconds([self playerItemDuration]);
    
    if (isfinite(duration)) {
        CGFloat width = CGRectGetWidth([self.scrubber bounds]);
        double interval = 0.5 * duration / width;
        
        /* The time label needs to update at least once per second. */
        if (interval > 1.0)
            interval = 1.0;
        __weak ViewController *weakSelf = self;
        _timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC) queue:dispatch_get_main_queue() usingBlock:
                         ^(CMTime time) {
                             [weakSelf updateScrubber];
                             [weakSelf updateTimeLabel];
                         }];
    }
}

- (void)removeTimeObserverFromPlayer
{
    if (_timeObserver) {
        [self.player removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
}

- (CMTime)playerItemDuration
{
    AVPlayerItem *playerItem = [self.player currentItem];
    CMTime itemDuration = kCMTimeInvalid;
    
    if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
        itemDuration = [playerItem duration];
    }
    
    /* Will be kCMTimeInvalid if the item is not ready to play. */
    return itemDuration;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == (__bridge void *)(AVCDVPlayerViewControllerRateObservationContext) ) {
        float newRate = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        NSNumber *oldRateNum = [change objectForKey:NSKeyValueChangeOldKey];
        if ( [oldRateNum isKindOfClass:[NSNumber class]] && newRate != [oldRateNum floatValue] ) {
            _playing = ((newRate != 0.f) || (_playRateToRestore != 0.f));
            [self updatePlayPauseButton];
            [self updateScrubber];
            [self updateTimeLabel];
        }
    }
    else if ( context == (__bridge void *)(AVCDVPlayerViewControllerStatusObservationContext) ) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
            // 加载完成可以读取duration属性
            
            [self addTimeObserverToPlayer];
        }
        else if (playerItem.status == AVPlayerItemStatusFailed) {
            [self reportError:playerItem.error];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    if (context != testContext) {
        //        NSLog(@"this also yes");
    }
}

- (void)updatePlayPauseButton
{
    UIBarButtonSystemItem style = _playing ? UIBarButtonSystemItemPause : UIBarButtonSystemItemPlay;
    UIBarButtonItem *newPlayPauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:style target:self action:@selector(togglePlayPause:)];
    
    NSMutableArray *items = [NSMutableArray arrayWithArray:self.toolbar.items];
    [items replaceObjectAtIndex:[items indexOfObject:self.playPauseButton] withObject:newPlayPauseButton];
    [self.toolbar setItems:items];
    
    self.playPauseButton = newPlayPauseButton;
}

- (void)updateTimeLabel
{
    double seconds = CMTimeGetSeconds([self.player currentTime]);
    if (!isfinite(seconds)) {
        seconds = 0;
    }
    
    int secondsInt = round(seconds);
    int minutes = secondsInt/60;
    secondsInt -= minutes*60;
    
    self.currentTimeLabel.textColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    self.currentTimeLabel.textAlignment = NSTextAlignmentCenter;
    
    self.currentTimeLabel.text = [NSString stringWithFormat:@"%.2i:%.2i", minutes, secondsInt];
}

- (void)updateScrubber
{
    double duration = CMTimeGetSeconds([self playerItemDuration]);
    
    if (isfinite(duration)) {
        double time = CMTimeGetSeconds([self.player currentTime]);
        [self.scrubber setValue:time / duration];
    }
    else {
        [self.scrubber setValue:0.0];
    }
}

- (void)reportError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                                message:[error localizedRecoverySuggestion]
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                      otherButtonTitles:nil];
            
            [alertView show];
        }
    });
}

#pragma mark - IBActions

- (void)togglePlayPause:(id)sender
{
    _playing = !_playing;
    if ( _playing ) {
        if ( _seekToZeroBeforePlaying ) {
            [self.player seekToTime:kCMTimeZero];
            _seekToZeroBeforePlaying = NO;
        }
        [self.player play];
    }
    else {
        [self.player pause];
    }
}

- (IBAction)beginScrubbing:(id)sender
{
    _seekToZeroBeforePlaying = NO;
    _playRateToRestore = [self.player rate];
    [self.player setRate:0.0];
    
    [self removeTimeObserverFromPlayer];
}

- (IBAction)scrub:(id)sender
{
    _lastScrubSliderValue = [self.scrubber value];
    
    if ( ! _scrubInFlight )
        [self scrubToSliderValue:_lastScrubSliderValue];
}

- (void)scrubToSliderValue:(float)sliderValue
{
    double duration = CMTimeGetSeconds([self playerItemDuration]);
    
    if (isfinite(duration)) {
        CGFloat width = CGRectGetWidth([self.scrubber bounds]);
        
        double time = duration*sliderValue;
        double tolerance = 1.0f * duration / width;
        
        _scrubInFlight = YES;
        
        [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)
                toleranceBefore:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC)
                 toleranceAfter:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC)
              completionHandler:^(BOOL finished) {
                  _scrubInFlight = NO;
                  [self updateTimeLabel];
              }];
    }
}

- (IBAction)endScrubbing:(id)sender
{
    if ( _scrubInFlight )
        [self scrubToSliderValue:_lastScrubSliderValue];
    [self addTimeObserverToPlayer];
    
    [self.player setRate:_playRateToRestore];
    _playRateToRestore = 0.f;
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    _seekToZeroBeforePlaying = YES;
}

@end
