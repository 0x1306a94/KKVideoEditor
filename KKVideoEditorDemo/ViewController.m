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
	[self buildComposition:^(AVMutableComposition *composition, AVMutableVideoComposition *videoComposition, AVMutableAudioMix *audioMix) {
		[hud hideAnimated:YES];

		AVPlayerItem *item    = [AVPlayerItem playerItemWithAsset:composition];
		item.videoComposition = videoComposition;
		item.audioMix         = audioMix;

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
		   if (CMTIME_COMPARE_INLINE(time, >=, item.duration)) {
				NSLog(@"end");
//				[self.player pause];
//				return;
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

- (void)buildComposition:(void (^)(AVMutableComposition *composition, AVMutableVideoComposition *videoComposition, AVMutableAudioMix *audioMix))completionHandler {
	AVMutableComposition *composition = [AVMutableComposition composition];
	CGSize naturalSize                = CGSizeMake(1280, 720);
	composition.naturalSize           = naturalSize;

	NSArray<AVMutableCompositionTrack *> *compositionVideoTracks = @[
		[composition addMutableTrackWithMediaType:AVMediaTypeVideo
		                         preferredTrackID:kCMPersistentTrackID_Invalid],
		[composition addMutableTrackWithMediaType:AVMediaTypeVideo
		                         preferredTrackID:kCMPersistentTrackID_Invalid],
	];

	NSArray<AVMutableCompositionTrack *> *compositionAudioTracks = @[
		[composition addMutableTrackWithMediaType:AVMediaTypeAudio
		                         preferredTrackID:kCMPersistentTrackID_Invalid],
		[composition addMutableTrackWithMediaType:AVMediaTypeAudio
		                         preferredTrackID:kCMPersistentTrackID_Invalid],
	];

	AVURLAsset *asset1 = [AVURLAsset URLAssetWithURL:[NSBundle.mainBundle URLForResource:@"bamboo" withExtension:@"mp4"] options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
	AVURLAsset *asset2 = [AVURLAsset URLAssetWithURL:[NSBundle.mainBundle URLForResource:@"sea" withExtension:@"mp4"] options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];

	NSArray<__kindof AVAsset *> *assets = @[asset1, asset2, asset1, asset2];

	NSArray<NSString *> *keys = @[
		@"tracks",
		@"duration",
		@"composable",
	];

	dispatch_group_t group = dispatch_group_create();
	dispatch_queue_t queue = dispatch_get_global_queue(0, 0);

	[assets enumerateObjectsUsingBlock:^(__kindof AVAsset *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
		[self preloadAsset:obj keys:keys queue:queue group:group];
	}];

	dispatch_block_t block = ^{
		__block CMTime cursorTime = kCMTimeZero;
		self.totalTime            = kCMTimeZero;
		CMTime transitionDuration = CMTimeMake(1, 1);

		NSInteger count = assets.count;

		CMTimeRange *passThroughTimeRanges = alloca(sizeof(CMTimeRange) * count);
		CMTimeRange *transitionTimeRanges  = alloca(sizeof(CMTimeRange) * count);

		for (NSInteger idx = 0; idx < count; idx++) {
			// 以 A B 轨排布
			// ------------------------------------
			// |  video 1  |          |   video 3 |    -----> A
			// ------------------------------------
			// |           | video 2  |                -----> B
			// ------------------------------------

			// 音频 同 视频 A B 轨排布
			AVMutableCompositionTrack *videoCompositionTrack = compositionVideoTracks[idx % 2];
			AVMutableCompositionTrack *audioCompositionTrack = compositionAudioTracks[idx % 2];

			AVAsset *obj = assets[idx];

			AVAssetTrack *videoTrack = [obj tracksWithMediaType:AVMediaTypeVideo].firstObject;
			AVAssetTrack *audioTrack = [obj tracksWithMediaType:AVMediaTypeAudio].firstObject;

			CMTimeRange assetTimeRange = CMTimeRangeMake(kCMTimeZero, obj.duration);

			[videoCompositionTrack insertTimeRange:assetTimeRange ofTrack:videoTrack atTime:cursorTime error:nil];
			[audioCompositionTrack insertTimeRange:assetTimeRange ofTrack:audioTrack atTime:cursorTime error:nil];

			passThroughTimeRanges[idx] = CMTimeRangeMake(cursorTime, assetTimeRange.duration);

			if (idx > 0) {
				passThroughTimeRanges[idx].start    = CMTimeAdd(passThroughTimeRanges[idx].start, transitionDuration);
				passThroughTimeRanges[idx].duration = CMTimeSubtract(passThroughTimeRanges[idx].duration, transitionDuration);
			}

			if (idx + 1 < count) {
				passThroughTimeRanges[idx].duration = CMTimeSubtract(passThroughTimeRanges[idx].duration, transitionDuration);
			}

			CMTimeShow(cursorTime);
			CMTimeRangeShow(passThroughTimeRanges[idx]);

			cursorTime = CMTimeAdd(cursorTime, assetTimeRange.duration);
			cursorTime = CMTimeSubtract(cursorTime, transitionDuration);

			if (idx + 1 < count) {
				transitionTimeRanges[idx] = CMTimeRangeMake(cursorTime, transitionDuration);
			}
		}

		NSMutableArray<KKVideoCompositionInstruction *> *instructions          = [NSMutableArray<KKVideoCompositionInstruction *> array];
		NSMutableArray<AVMutableAudioMixInputParameters *> *audioMixParameters = [NSMutableArray<AVMutableAudioMixInputParameters *> array];

		for (NSInteger idx = 0; idx < count; idx++) {
			AVMutableCompositionTrack *curVideoTrack  = compositionVideoTracks[idx % 2];
			AVMutableCompositionTrack *nextVideoTrack = compositionVideoTracks[(idx + 1) % 2];

			AVMutableCompositionTrack *curAudioTrack  = compositionAudioTracks[idx % 2];
			AVMutableCompositionTrack *nextAudioTrack = compositionAudioTracks[(idx + 1) % 2];

			KKVideoCompositionInstruction *passThroughInstruction = [[KKVideoCompositionInstruction alloc] initWithSourceTrackIDs:@[@(curVideoTrack.trackID)] timeRange:passThroughTimeRanges[idx]];

			AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:curVideoTrack];
			passThroughInstruction.layerInstructions                    = @[passThroughLayer];

			[instructions addObject:passThroughInstruction];

			AVMutableAudioMixInputParameters *passThroughAudioMix = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:curAudioTrack];
			[passThroughAudioMix setVolumeRampFromStartVolume:1 toEndVolume:1 timeRange:passThroughTimeRanges[idx]];

			[audioMixParameters addObject:passThroughAudioMix];

			if (idx + 1 < count) {
				KKVideoCompositionInstruction *transitionInstruction = [[KKVideoCompositionInstruction alloc] initWithSourceTrackIDs:@[@(curVideoTrack.trackID), @(nextVideoTrack.trackID)] timeRange:transitionTimeRanges[idx]];

				AVMutableVideoCompositionLayerInstruction *fromLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:curVideoTrack];  //当前视频track

				AVMutableVideoCompositionLayerInstruction *toLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:nextVideoTrack];  //下一个视频track

				[fromLayer setOpacityRampFromStartOpacity:1.0 toEndOpacity:0.0 timeRange:transitionTimeRanges[idx]];
				[fromLayer setTransformRampFromStartTransform:CGAffineTransformMakeTranslation(0, 0) toEndTransform:CGAffineTransformMakeTranslation(-naturalSize.width, 0) timeRange:transitionTimeRanges[idx]];

				[toLayer setTransformRampFromStartTransform:CGAffineTransformMakeTranslation(naturalSize.width, 0) toEndTransform:CGAffineTransformIdentity timeRange:transitionTimeRanges[idx]];
				[toLayer setOpacityRampFromStartOpacity:0 toEndOpacity:0.5 timeRange:transitionTimeRanges[idx]];

				transitionInstruction.layerInstructions = @[fromLayer, toLayer];

				[instructions addObject:transitionInstruction];

				AVMutableAudioMixInputParameters *fromAudioMix = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:curAudioTrack];
				AVMutableAudioMixInputParameters *toAudioMix   = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:nextAudioTrack];

				[fromAudioMix setVolumeRampFromStartVolume:1 toEndVolume:0 timeRange:transitionTimeRanges[idx]];
				[toAudioMix setVolumeRampFromStartVolume:0 toEndVolume:1 timeRange:transitionTimeRanges[idx]];

				[audioMixParameters addObject:fromAudioMix];
				[audioMixParameters addObject:toAudioMix];
			}
		}

		CMTimeShow(composition.duration);

		// 添加的指令序列 总时长 需要和 音频轨道总时长一致, 否则会导致 指令序列不会被执行
		AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
		videoComposition.frameDuration              = CMTimeMake(1, 30);
		videoComposition.renderSize                 = composition.naturalSize;
		videoComposition.instructions               = instructions;
		videoComposition.customVideoCompositorClass = KKVideoCompositor.class;

		AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
		audioMix.inputParameters    = audioMixParameters;

		!completionHandler ?: completionHandler(composition, videoComposition, audioMix);
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

