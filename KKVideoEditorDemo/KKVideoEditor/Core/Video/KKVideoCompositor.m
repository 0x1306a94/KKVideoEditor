//
//  KKVideoCompositor.m
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import "KKCMTimeExtension.h"
#import "KKVideoCompositionInstruction.h"
#import "KKVideoCompositor.h"
#import "KKVideoEditorFactory.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>

@interface KKVideoCompositor ()
@property (nonatomic, strong) dispatch_queue_t renderContextQueue;
@property (nonatomic, strong) dispatch_queue_t renderingQueue;
@property (nonatomic, assign) BOOL renderContextDidChange;
@property (nonatomic, assign) BOOL shouldCancelAllRequests;
@property (nonatomic, strong) AVVideoCompositionRenderContext *renderContext;

@property (nonatomic, assign) CGColorSpaceRef colorSpaceRef;
@end

@implementation KKVideoCompositor
+ (CIContext *)sharedCIContext {
	static CIContext *__context__ = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		// 内部的渲染器会根据设备最优选择。依次为 Metal，OpenGLES，CoreGraphics。
		__context__ = [CIContext contextWithOptions:nil];
	});
	return __context__;
}

- (instancetype)init {
	if (self == [super init]) {
		[self commonInit];
	}
	return self;
}

- (void)commonInit {
	_renderContextQueue      = dispatch_queue_create("com.0x1306a94.videoeditor.renderContextQueue", DISPATCH_QUEUE_SERIAL);
	_renderingQueue          = dispatch_queue_create("com.0x1306a94.videoeditor.renderingQueue", DISPATCH_QUEUE_SERIAL);
	_renderContextDidChange  = NO;
	_shouldCancelAllRequests = NO;

	_colorSpaceRef = CGColorSpaceCreateWithName(kCGColorSpaceSRGB) ?: CGColorSpaceCreateDeviceRGB();

	_sourcePixelBufferAttributes = @{
		(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
		(__bridge NSString *)kCVPixelBufferOpenGLESCompatibilityKey: @YES,
	};

	_requiredPixelBufferAttributesForRenderContext = @{
		(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
		(__bridge NSString *)kCVPixelBufferOpenGLESCompatibilityKey: @YES,
	};
}

#pragma mark - private
- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request {
	if (request.sourceTrackIDs.count == 0) return NULL;

	if (!request.videoCompositionInstruction || ![request.videoCompositionInstruction isKindOfClass:KKVideoCompositionInstruction.class]) {
		NSNumber *trackID = request.sourceTrackIDs.firstObject;
		return [request sourceFrameByTrackID:(CMPersistentTrackID)trackID.integerValue];
	}

	CVPixelBufferRef outputPixels = [self.renderContext newPixelBuffer];

	KKVideoCompositionInstruction *instruction = (KKVideoCompositionInstruction *)request.videoCompositionInstruction;

	CGRect extent = {0, 0, request.renderContext.size};
	// Background
	CIImage *backgroundImage = [[CIImage imageWithColor:instruction.backgroundColor] imageByCroppingToRect:extent];

	BOOL dealed = NO;
	if (instruction.layerInstructions.count > 0) {
		for (AVMutableVideoCompositionLayerInstruction *layerInstruction in instruction.layerInstructions) {
			CVPixelBufferRef frameBuffer = [request sourceFrameByTrackID:layerInstruction.trackID];
			if (frameBuffer == NULL) {
				continue;
			}
			CIImage *srcImage = [CIImage imageWithCVPixelBuffer:frameBuffer];
			if (!CGSizeEqualToSize(srcImage.extent.size, extent.size)) {
				CGFloat sx = CGRectGetWidth(extent) / CGRectGetWidth(srcImage.extent);
				CGFloat sy = CGRectGetHeight(extent) / CGRectGetHeight(srcImage.extent);
				srcImage   = [srcImage imageByApplyingTransform:CGAffineTransformMakeScale(sx, sy)];
			}
			CMTime time = request.compositionTime;
			{
				float startOpacity    = 0;
				float endOpacity      = 1.0;
				CMTimeRange timeRange = kCMTimeRangeInvalid;
				BOOL needApply        = NO;
				float opacity         = 1.0;
				if ([layerInstruction getOpacityRampForTime:time startOpacity:&startOpacity endOpacity:&endOpacity timeRange:&timeRange]) {
					if (CMTIMERANGE_IS_VALID(timeRange) && CMTimeRangeContainsTime(timeRange, time)) {
						needApply       = YES;
						CGFloat percent = kk_factorForTimeInRange(request.compositionTime, timeRange);
						if (endOpacity > startOpacity) {
							opacity = percent * (endOpacity - startOpacity) + startOpacity;
						} else if (startOpacity > endOpacity) {
							opacity = percent * (startOpacity - endOpacity) + endOpacity;
						} else {
							opacity = endOpacity;
						}
					}
				}
				if (needApply) {
					CGFloat values[]      = {0, 0, 0, opacity};
					CIVector *alphaVector = [CIVector vectorWithValues:values count:4];
					srcImage              = [srcImage imageByApplyingFilter:@"CIColorMatrix" withInputParameters:@{@"inputAVector": alphaVector}];
				}
			}

			{
				CGAffineTransform startTransform = CGAffineTransformIdentity;
				CGAffineTransform endTransform   = CGAffineTransformIdentity;
				CMTimeRange timeRange            = kCMTimeRangeInvalid;
				if ([layerInstruction getTransformRampForTime:time startTransform:&startTransform endTransform:&endTransform timeRange:&timeRange]) {
					if (CMTIMERANGE_IS_VALID(timeRange) && CMTimeRangeContainsTime(timeRange, time)) {
						CGAffineTransform transform = CGAffineTransformIdentity;
						CGFloat percent             = kk_factorForTimeInRange(request.compositionTime, timeRange);
						{
							CGFloat sx = startTransform.a + (endTransform.a - startTransform.a) * percent;
							CGFloat sy = startTransform.d + (endTransform.d - startTransform.d) * percent;
							transform  = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(sx, sy));
						}

						{

							CGFloat rotaion = acos(startTransform.a) + (acos(endTransform.a) - acos(startTransform.a)) * percent;
							transform       = CGAffineTransformConcat(transform, CGAffineTransformMakeRotation(rotaion));
						}

						{
							CGFloat tx = startTransform.tx + (endTransform.tx - startTransform.tx) * percent;
							CGFloat ty = startTransform.ty + (endTransform.ty - startTransform.ty) * percent;
							transform  = CGAffineTransformConcat(transform, CGAffineTransformMakeTranslation(tx, ty));
						}

						srcImage = [srcImage imageByApplyingTransform:transform];
					}
				}
			}

			if (srcImage) {
				dealed          = YES;
				backgroundImage = [srcImage imageByCompositingOverImage:backgroundImage];
			}
		}
	}
	if (!dealed) {

		NSNumber *trackID            = request.sourceTrackIDs.firstObject;
		CVPixelBufferRef frameBuffer = [request sourceFrameByTrackID:(CMPersistentTrackID)trackID.integerValue];
		if (frameBuffer) {
			CIImage *srcImage = [CIImage imageWithCVPixelBuffer:frameBuffer];
			if (!CGSizeEqualToSize(srcImage.extent.size, extent.size)) {
				CGFloat sx = CGRectGetWidth(extent) / CGRectGetWidth(srcImage.extent);
				CGFloat sy = CGRectGetHeight(extent) / CGRectGetHeight(srcImage.extent);
				srcImage   = [srcImage imageByApplyingTransform:CGAffineTransformMakeScale(sx, sy)];
			}
			backgroundImage = [srcImage imageByCompositingOverImage:backgroundImage];
		}
	}
	[[KKVideoCompositor sharedCIContext] render:backgroundImage toCVPixelBuffer:outputPixels bounds:backgroundImage.extent colorSpace:self.colorSpaceRef];
	return outputPixels;
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {
	__weak typeof(self) weakSelf = self;
	dispatch_sync(self.renderContextQueue, ^{
		__strong typeof(self) self = weakSelf;
		if (!self) {
			return;
		}

		self.renderContext          = newRenderContext;
		self.renderContextDidChange = YES;
	});
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
	__weak typeof(self) weakSelf = self;
	dispatch_async(self.renderingQueue, ^{
		__strong typeof(self) self = weakSelf;
		if (!self) {
			return;
		}
		if (self.shouldCancelAllRequests) {
			[request finishCancelledRequest];
			return;
		}
		@autoreleasepool {
			CVPixelBufferRef resultPixels = [self newRenderedPixelBufferForRequest:request];
			if (resultPixels) {
				[request finishWithComposedVideoFrame:resultPixels];
				// 释放内存,否则会持续增长内存,最终导致crash
				CVPixelBufferRelease(resultPixels);
			} else {
				[request finishWithError:[NSError errorWithDomain:@"VideoEditor" code:400 userInfo:nil]];
			}
		}
	});
}

- (void)cancelAllPendingVideoCompositionRequests {
	self.shouldCancelAllRequests = YES;
	__weak typeof(self) weakSelf = self;
	dispatch_barrier_async(self.renderingQueue, ^{
		__strong typeof(self) self = weakSelf;
		if (!self) {
			return;
		}
		self.shouldCancelAllRequests = NO;
	});
}

- (void)dealloc {
	if (self.colorSpaceRef) {
		CGColorSpaceRelease(self.colorSpaceRef);
	}
}
@end

