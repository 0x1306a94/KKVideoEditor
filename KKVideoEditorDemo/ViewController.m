//
//  ViewController.m
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import "KKVideoCompositionInstruction.h"
#import "KKVideoCompositor.h"
#import "KKVideoEditorPreviewView.h"
#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>

@interface ViewController ()
@property (nonatomic, weak) IBOutlet KKVideoEditorPreviewView *previewView;

@property (nonatomic, strong) AVMutableComposition *composition;
@property (nonatomic, strong) AVMutableCompositionTrack *videoCompositionTrack;
@property (nonatomic, strong) AVMutableCompositionTrack *audioCompositionTrack;
@property (nonatomic, strong) AVMutableVideoComposition *videoComposition;

@property (nonatomic, strong) AVAsset *emptyAsset;

@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, strong) id periodicTimeObserver;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (IBAction)startPreview:(UIButton *)sender {
    [self buildPlayer];
}

- (IBAction)stopPreview:(UIButton *)sender {
    if (self.player) {
        if (self.periodicTimeObserver) {
            [self.player removeTimeObserver:self.periodicTimeObserver];
        }
        [self.player pause];
        self.player = nil;
    }
    self.periodicTimeObserver = nil;
}

- (void)buildPlayer {
    [self buildComposition];

    AVPlayerItem *item    = [AVPlayerItem playerItemWithAsset:self.composition];
    item.videoComposition = self.videoComposition;

    if (self.player) {
        [self.player replaceCurrentItemWithPlayerItem:item];
    } else {
        self.player = [AVPlayer playerWithPlayerItem:item];
    }

    [self.previewView attachPlayer:self.player];

    if (self.periodicTimeObserver) {
        [self.player removeTimeObserver:self.periodicTimeObserver];
        self.periodicTimeObserver = nil;
    }
    __weak typeof(self) weakSelf = self;
    /* clang-format off */
   self.periodicTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(600, 600) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        __strong typeof(self) self = weakSelf;
        if (!self) {
            return;
        }
//        CMTimeShow(time);
        if (CMTIME_COMPARE_INLINE(time, >=, item.duration)) {
            [self.player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
                __strong typeof(self) self = weakSelf;
                if (!self) {
                    return;
                }
                if (finished) {
                    [self.player play];
                }
            }];
        }
    }];
    /* clang-format on */

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [self.player play];
}

- (void)buildComposition {
    self.composition = [AVMutableComposition compositionWithURLAssetInitializationOptions:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];

    self.videoCompositionTrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    self.audioCompositionTrack = [self.composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    int32_t timescale          = 600;
    //    {
    //        CMTime duration          = CMTimeMake(10 * timescale, timescale);
    //        AVAssetTrack *videoTrack = [self.emptyAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    //        [self.videoCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:nil];
    //    }
    {
        NSURL *url               = [NSBundle.mainBundle URLForResource:@"bamboo" withExtension:@"mp4"];
        AVAsset *asset           = [AVAsset assetWithURL:url];
        AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        CMTime duration          = CMTimeMake(5 * timescale, timescale);
        NSError *error           = nil;
        [self.videoCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:&error];
        if (error) {
            NSLog(@"%@", error);
            return;
        }

        AVAssetTrack *audioTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        [self.audioCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:audioTrack atTime:kCMTimeZero error:&error];
        if (error) {
            NSLog(@"%@", error);
            return;
        }
    }

    {
        NSURL *url               = [NSBundle.mainBundle URLForResource:@"sea" withExtension:@"mp4"];
        AVAsset *asset           = [AVAsset assetWithURL:url];
        AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        CMTime duration          = CMTimeMake(5 * timescale, timescale);
        CMTime start             = CMTimeMake(5 * timescale, timescale);
        NSError *error           = nil;
        [self.videoCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:start error:&error];
        if (error) {
            NSLog(@"%@", error);
            return;
        }

        AVAssetTrack *audioTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        [self.audioCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:audioTrack atTime:start error:&error];
        if (error) {
            NSLog(@"%@", error);
            return;
        }
    }

    KKVideoCompositionInstruction *instruction1 = [[KKVideoCompositionInstruction alloc] initWithTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(5 * timescale, timescale))];
    instruction1.backgroundColor                = [CIColor colorWithCGColor:UIColor.greenColor.CGColor];
    {
        NSURL *url                = [NSBundle.mainBundle URLForResource:@"IMG_2629" withExtension:@"jpeg"];
        CIImage *overlayImage     = [CIImage imageWithContentsOfURL:url];
        overlayImage              = [overlayImage imageByApplyingTransform:CGAffineTransformMakeScale(0.35, 0.35)];
        instruction1.overlayImage = overlayImage;
        instruction1.filterName   = @"CIPhotoEffectProcess";
    }

    KKVideoCompositionInstruction *instruction2 = [[KKVideoCompositionInstruction alloc] initWithTimeRange:CMTimeRangeMake(CMTimeMake(5 * timescale, timescale), CMTimeMake(5 * timescale, timescale))];
    instruction2.backgroundColor                = [CIColor colorWithCGColor:UIColor.blackColor.CGColor];
    {
        NSURL *url                = [NSBundle.mainBundle URLForResource:@"IMG_3451" withExtension:@"jpeg"];
        CIImage *overlayImage     = [CIImage imageWithContentsOfURL:url];
        overlayImage              = [overlayImage imageByApplyingTransform:CGAffineTransformMakeScale(0.35, 0.35)];
        instruction2.overlayImage = overlayImage;
        instruction2.filterName   = @"CIPhotoEffectTransfer";
    }

    self.videoComposition               = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:self.composition];
    self.videoComposition.frameDuration = CMTimeMake(1, 30);
    self.videoComposition.renderSize    = CGSizeMake(1280, 720);
    self.videoComposition.instructions  = @[
        instruction1,
        instruction2,
    ];
    self.videoComposition.customVideoCompositorClass = KKVideoCompositor.class;
}

#pragma mark - getter
- (AVAsset *)emptyAsset {
    if (!_emptyAsset) {
        NSURL *url  = [NSBundle.mainBundle URLForResource:@"black_empty" withExtension:@"mp4"];
        _emptyAsset = [AVAsset assetWithURL:url];
    }
    return _emptyAsset;
}
@end

