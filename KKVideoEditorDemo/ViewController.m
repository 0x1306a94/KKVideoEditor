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

	[self buildComposition:^(AVMutableComposition *composition, AVMutableVideoComposition *videoComposition) {
		AVPlayerItem *item    = [AVPlayerItem playerItemWithAsset:composition];
		item.videoComposition = videoComposition;

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
	}];
}

- (void)buildComposition:(void (^)(AVMutableComposition *composition, AVMutableVideoComposition *videoComposition))completionHandler {
	AVMutableComposition *composition = [AVMutableComposition compositionWithURLAssetInitializationOptions:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
	composition.naturalSize           = CGSizeMake(1280, 720);

	AVMutableCompositionTrack *videoCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
	AVMutableCompositionTrack *audioCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];

	int32_t timescale = 600;

	AVAsset *asset  = [AVAsset assetWithURL:[NSBundle.mainBundle URLForResource:@"bamboo" withExtension:@"mp4"]];
	AVAsset *asset2 = [AVAsset assetWithURL:[NSBundle.mainBundle URLForResource:@"sea" withExtension:@"mp4"]];

	NSArray<NSString *> *keys = @[@"tracks", @"duration"];

	dispatch_group_t group = dispatch_group_create();
	dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
	dispatch_group_enter(group);
	dispatch_group_async(group, queue, ^{
		__block int count = 0;
		/* clang-format off */
		[asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
			NSLog(@"asset loadValuesAsynchronouslyForKeys");
			if ([asset statusOfValueForKey:@"tracks" error:nil] == AVKeyValueStatusLoaded) {
				count++;
			}

			if ([asset statusOfValueForKey:@"duration" error:nil] == AVKeyValueStatusLoaded) {
				count++;
			}
			if (count == keys.count) {
				dispatch_group_leave(group);
			}
		}];
		/* clang-format on */
	});

	dispatch_group_enter(group);
	dispatch_group_async(group, queue, ^{
		__block int count = 0;
		/* clang-format off */
		[asset2 loadValuesAsynchronouslyForKeys:keys completionHandler:^{
			NSLog(@"asset2 loadValuesAsynchronouslyForKeys");
			if ([asset statusOfValueForKey:@"tracks" error:nil] == AVKeyValueStatusLoaded) {
				count++;
			}

			if ([asset statusOfValueForKey:@"duration" error:nil] == AVKeyValueStatusLoaded) {
				count++;
			}
			if (count == keys.count) {
				dispatch_group_leave(group);
			}
		}];
		/* clang-format on */
	});

	dispatch_block_t block = ^{
		CMTimeRange *timeRanges = alloca(sizeof(CMTimeRange) * 2);
		CMTime *startTimes      = alloca(sizeof(CMTime) * 2);

		{
			AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
			timeRanges[0]            = CMTimeRangeMake(kCMTimeZero, CMTimeMake(CMTimeGetSeconds(asset.duration) * timescale, timescale));
			startTimes[0]            = kCMTimeZero;
			NSError *error           = nil;
			[videoCompositionTrack insertTimeRange:timeRanges[0] ofTrack:videoTrack atTime:startTimes[0] error:&error];
			if (error) {
				NSLog(@"%@", error);
				return;
			}

			AVAssetTrack *audioTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
			[audioCompositionTrack insertTimeRange:timeRanges[0] ofTrack:audioTrack atTime:startTimes[0] error:&error];
			if (error) {
				NSLog(@"%@", error);
				return;
			}
		}

		{
			AVAssetTrack *videoTrack = [asset2 tracksWithMediaType:AVMediaTypeVideo].firstObject;

			timeRanges[1] = CMTimeRangeMake(timeRanges[0].duration, CMTimeMake(CMTimeGetSeconds(asset2.duration) * timescale, timescale));
			startTimes[1] = timeRanges[0].duration;

			NSError *error = nil;
			[videoCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(CMTimeGetSeconds(asset2.duration) * timescale, timescale)) ofTrack:videoTrack atTime:startTimes[1] error:&error];
			if (error) {
				NSLog(@"%@", error);
				return;
			}

			AVAssetTrack *audioTrack = [asset2 tracksWithMediaType:AVMediaTypeAudio].firstObject;
			[audioCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(CMTimeGetSeconds(asset2.duration) * timescale, timescale)) ofTrack:audioTrack atTime:startTimes[1] error:&error];
			if (error) {
				NSLog(@"%@", error);
				return;
			}
		}

		KKVideoCompositionInstruction *instruction1 = [[KKVideoCompositionInstruction alloc] initWithTimeRange:timeRanges[0]];
		instruction1.backgroundColor                = [CIColor colorWithCGColor:UIColor.greenColor.CGColor];
		{
			NSURL *url                = [NSBundle.mainBundle URLForResource:@"IMG_2629" withExtension:@"jpeg"];
			CIImage *overlayImage     = [CIImage imageWithContentsOfURL:url];
			overlayImage              = [overlayImage imageByApplyingTransform:CGAffineTransformMakeScale(0.35, 0.35)];
			instruction1.overlayImage = overlayImage;
			instruction1.filterName   = @"CIPhotoEffectInstant";
		}

		KKVideoCompositionInstruction *instruction2 = [[KKVideoCompositionInstruction alloc] initWithTimeRange:timeRanges[1]];
		instruction2.backgroundColor                = [CIColor colorWithCGColor:UIColor.blackColor.CGColor];
		{
			NSURL *url                = [NSBundle.mainBundle URLForResource:@"IMG_3451" withExtension:@"jpeg"];
			CIImage *overlayImage     = [CIImage imageWithContentsOfURL:url];
			overlayImage              = [overlayImage imageByApplyingTransform:CGAffineTransformMakeScale(0.35, 0.35)];
			instruction2.overlayImage = overlayImage;
			instruction2.filterName   = @"CIPhotoEffectTransfer";
		}

		AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoCompositionWithPropertiesOfAsset:composition];
		videoComposition.frameDuration              = CMTimeMake(1, 30);
		videoComposition.renderSize                 = composition.naturalSize;
		videoComposition.instructions               = @[
            instruction1,
            instruction2,
		];
		videoComposition.customVideoCompositorClass = KKVideoCompositor.class;

		!completionHandler ?: completionHandler(composition, videoComposition);
	};

	dispatch_group_notify(group, dispatch_get_main_queue(), block);
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

