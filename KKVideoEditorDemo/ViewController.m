//
//  ViewController.m
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import "KKCMTimeExtension.h"
#import "KKVideoCompositionInstruction.h"
#import "KKVideoCompositor.h"
#import "KKVideoEditorPreviewView.h"
#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>

#import <MBProgressHUD/MBProgressHUD.h>

@interface ViewController ()
@property (nonatomic, weak) IBOutlet KKVideoEditorPreviewView *previewView;

@property (nonatomic, strong) AVMutableComposition *composition;
@property (nonatomic, strong) AVMutableCompositionTrack *videoCompositionTrack;
@property (nonatomic, strong) AVMutableCompositionTrack *audioCompositionTrack;
@property (nonatomic, strong) AVMutableVideoComposition *videoComposition;

@property (nonatomic, strong) AVAsset *emptyAsset;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, assign) CMTime totalTime;
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

	__block MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view.window animated:YES];
	hud.backgroundColor        = [UIColor.blackColor colorWithAlphaComponent:0.6];
	hud.mode                   = MBProgressHUDModeAnnularDeterminate;
	[self buildComposition:^(AVMutableComposition *composition, AVMutableVideoComposition *videoComposition) {
		[hud hideAnimated:YES];

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
//	        CMTimeShow(time);
			if (CMTIME_COMPARE_INLINE(time, >=, self.totalTime)) {
				[self.player pause];
				return;
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

	AVMutableCompositionTrack *videoCompositionTrackA = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
	AVMutableCompositionTrack *videoCompositionTrackB = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];

	NSArray<AVMutableCompositionTrack *> *videoTracks = @[videoCompositionTrackA, videoCompositionTrackB];

	AVMutableCompositionTrack *audioCompositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];

	AVURLAsset *asset1 = [AVURLAsset URLAssetWithURL:[NSBundle.mainBundle URLForResource:@"bamboo" withExtension:@"mp4"] options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
	AVURLAsset *asset2 = [AVURLAsset URLAssetWithURL:[NSBundle.mainBundle URLForResource:@"sea" withExtension:@"mp4"] options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];

	NSArray<__kindof AVAsset *> *assets = @[asset1, asset2];

	NSArray<NSString *> *keys = @[@"tracks", @"duration"];

	dispatch_group_t group = dispatch_group_create();
	dispatch_queue_t queue = dispatch_get_global_queue(0, 0);

	[assets enumerateObjectsUsingBlock:^(__kindof AVAsset *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
		[self preloadAsset:obj keys:keys queue:queue group:group];
	}];

	dispatch_block_t block = ^{
		CMTimeRange *timeRanges = alloca(sizeof(CMTimeRange) * 2);

		__block CMTime cursorTime = kCMTimeZero;
		self.totalTime            = kCMTimeZero;
		CMTime transitionDuration = CMTimeMake(2 * kkVideoEditorCommonTimeScale, kkVideoEditorCommonTimeScale);

		NSInteger count = assets.count;
		for (NSInteger idx = 0; idx < count; idx++) {
			// 以 A B 轨排布
			// ------------------------------------
			// |  video 1  |          |   video 3 |    -----> A
			// ------------------------------------
			// |           | video 2  |                -----> B
			// ------------------------------------
			AVMutableCompositionTrack *videoCompositionTrack = videoTracks[idx % 2];

			AVAsset *obj = assets[idx];

			AVAssetTrack *videoTrack    = [obj tracksWithMediaType:AVMediaTypeVideo].firstObject;
			AVAssetTrack *audioTrack    = [obj tracksWithMediaType:AVMediaTypeAudio].firstObject;
			CMTimeRange insertTimeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake(CMTimeGetSeconds(obj.duration) * kkVideoEditorCommonTimeScale, kkVideoEditorCommonTimeScale));
			timeRanges[idx]             = insertTimeRange;
			[videoCompositionTrack insertTimeRange:insertTimeRange ofTrack:videoTrack atTime:cursorTime error:nil];
			[audioCompositionTrack insertTimeRange:insertTimeRange ofTrack:audioTrack atTime:cursorTime error:nil];
			//光标移动到视频末尾处，以便插入下一段视频
			cursorTime = CMTimeAdd(cursorTime, insertTimeRange.duration);
			CMTimeShow(cursorTime);
			//光标回退转场动画时长的距离，这一段前后视频重叠部分组合成转场动画
			if (idx < (count - 1)) {
				cursorTime = CMTimeSubtract(cursorTime, transitionDuration);
			}
		}

		// AVMutableComposition 的 duration 为所有片段总时长, 但由于添加了转场,所以应该减去转场时长
		self.totalTime = cursorTime;
		CMTimeShow(self.totalTime);

		KKVideoCompositionInstruction *instruction1                  = [[KKVideoCompositionInstruction alloc] initWithSourceTrackIDs:@[@1, @2] timeRange:CMTimeRangeMake(kCMTimeZero, timeRanges[0].duration)];
		AVMutableVideoCompositionLayerInstruction *layerInstruction1 = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];
		layerInstruction1.trackID                                    = 1;
		[layerInstruction1 setOpacityRampFromStartOpacity:1.0 toEndOpacity:0.0 timeRange:CMTimeRangeMake(CMTimeMake(3 * kkVideoEditorCommonTimeScale, kkVideoEditorCommonTimeScale), transitionDuration)];
		[layerInstruction1 setTransformRampFromStartTransform:CGAffineTransformMakeTranslation(0, 0) toEndTransform:CGAffineTransformMakeTranslation(-1280, 0) timeRange:CMTimeRangeMake(CMTimeMake(3 * kkVideoEditorCommonTimeScale, kkVideoEditorCommonTimeScale), transitionDuration)];
		AVMutableVideoCompositionLayerInstruction *layerInstruction2 = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstruction];
		layerInstruction2.trackID                                    = 2;
		[layerInstruction2 setTransformRampFromStartTransform:CGAffineTransformMakeTranslation(1280, 0) toEndTransform:CGAffineTransformIdentity timeRange:CMTimeRangeMake(CMTimeMake(3 * kkVideoEditorCommonTimeScale, kkVideoEditorCommonTimeScale), transitionDuration)];
		[layerInstruction2 setOpacityRampFromStartOpacity:0 toEndOpacity:1.0 timeRange:CMTimeRangeMake(CMTimeMake(3 * kkVideoEditorCommonTimeScale, kkVideoEditorCommonTimeScale), transitionDuration)];

		instruction1.layerInstructions = @[layerInstruction1, layerInstruction2];
		instruction1.backgroundColor   = [CIColor colorWithCGColor:UIColor.blackColor.CGColor];

		KKVideoCompositionInstruction *instruction2 = [[KKVideoCompositionInstruction alloc] initWithSourceTrackIDs:@[@2] timeRange:CMTimeRangeMake(timeRanges[0].duration, timeRanges[1].duration)];
		instruction2.backgroundColor                = [CIColor colorWithCGColor:UIColor.blackColor.CGColor];

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

- (void)preloadAsset:(AVAsset *)asset keys:(NSArray<NSString *> *)keys queue:(dispatch_queue_t)queue group:(dispatch_group_t)group {
	dispatch_group_enter(group);
	dispatch_group_async(group, queue, ^{
		/* clang-format off */
		[asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
			NSLog(@"asset loadValuesAsynchronouslyForKeys");
			dispatch_group_leave(group);
		}];
		/* clang-format on */
	});
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

