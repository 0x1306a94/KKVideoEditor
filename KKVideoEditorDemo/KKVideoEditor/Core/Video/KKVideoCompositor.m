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
    CVPixelBufferRef frameBuffer  = NULL;
    CVPixelBufferRef outputPixels = [self.renderContext newPixelBuffer];
    if (request.sourceTrackIDs.count > 0) {
        NSNumber *trackID = request.sourceTrackIDs.firstObject;
        frameBuffer       = [request sourceFrameByTrackID:(CMPersistentTrackID)trackID.integerValue];
        if (frameBuffer == NULL) {
            return outputPixels;
        }
    }

    if (frameBuffer == NULL) {
        return outputPixels;
    }
    if (!request.videoCompositionInstruction || ![request.videoCompositionInstruction isKindOfClass:KKVideoCompositionInstruction.class]) {
        return frameBuffer ? frameBuffer : outputPixels;
    }
    KKVideoCompositionInstruction *instruction = (KKVideoCompositionInstruction *)request.videoCompositionInstruction;

    CMTimeRange timeRange = instruction.timeRange;

    // 原始帧
    CIImage *srcImage = [CIImage imageWithCVPixelBuffer:frameBuffer];
    // 最终输出帧
    CIImage *desImage = [CIImage imageWithCVPixelBuffer:outputPixels];

    //    srcImage = [srcImage imageByCroppingToRect:desImage.extent];

    if (!CGSizeEqualToSize(srcImage.extent.size, desImage.extent.size)) {
        CGFloat tx = (CGRectGetWidth(desImage.extent) - CGRectGetWidth(srcImage.extent)) * 0.5;
        CGFloat ty = (CGRectGetHeight(desImage.extent) - CGRectGetHeight(srcImage.extent)) * 0.5;
        srcImage   = [srcImage imageByApplyingTransform:CGAffineTransformMakeTranslation(tx, ty)];

        //        CGFloat sx = CGRectGetWidth(desImage.extent) / CGRectGetWidth(srcImage.extent);
        //        CGFloat sy = CGRectGetHeight(desImage.extent) / CGRectGetHeight(srcImage.extent);
        //        srcImage   = [srcImage imageByApplyingTransform:CGAffineTransformMakeScale(sx, sy)];
    }
    // Background
    CIImage *backgroundImage = [[CIImage imageWithColor:instruction.backgroundColor] imageByCroppingToRect:desImage.extent];

    CGFloat percent = kk_factorForTimeInRange(request.compositionTime, timeRange);
    //    CGSize overlaySize = CGSizeMake(300, 300);
    //
    //    CGRect overlayRect    = (CGRect){0, 0, overlaySize};
    CIImage *overlayImage = instruction.overlayImage;

#warning 测试
    if (CMTIME_COMPARE_INLINE(timeRange.start, <=, kCMTimeZero)) {
        CGFloat tx = CGRectGetWidth(desImage.extent) * percent;
        CGFloat ty = (CGRectGetHeight(desImage.extent) - CGRectGetHeight(overlayImage.extent)) * 0.5;

        //        CIColor *startColor   = CIColor.redColor;
        //        CIColor *endColor     = CIColor.greenColor;
        //        CIColor *overlayColor = kk_interpolationCIColorFrom(startColor, endColor, percent);

        //        overlayImage = [[CIImage imageWithColor:overlayColor] imageByCroppingToRect:overlayRect];
        //        CGFloat angle = ((percent * 90) * (M_PI / 180.0));

        overlayImage = [overlayImage imageByApplyingTransform:CGAffineTransformMakeTranslation(tx, ty)];
        //        overlayImage = [overlayImage imageByApplyingTransform:CGAffineTransformMakeRotation(angle)];
    } else {
        CGFloat tx = CGRectGetWidth(desImage.extent) - (CGRectGetWidth(desImage.extent) + CGRectGetWidth(overlayImage.extent)) * percent;
        CGFloat ty = (CGRectGetHeight(desImage.extent) - CGRectGetHeight(overlayImage.extent)) * 0.5;

        //        CIColor *startColor   = CIColor.yellowColor;
        //        CIColor *endColor     = CIColor.blueColor;
        //        CIColor *overlayColor = kk_interpolationCIColorFrom(startColor, endColor, percent);

        //        overlayImage = [[CIImage imageWithColor:overlayColor] imageByCroppingToRect:overlayRect];

        //        CGFloat angle = ((percent * 90) * (M_PI / 180.0));

        overlayImage = [overlayImage imageByApplyingTransform:CGAffineTransformMakeTranslation(tx, ty)];
        //        overlayImage = [overlayImage imageByApplyingTransform:CGAffineTransformMakeRotation(-angle)];
    }
    if (instruction.filterName.length > 0) {
        srcImage = [srcImage imageByApplyingFilter:instruction.filterName];
    }
//    srcImage = [srcImage imageByApplyingFilter:@"CIMotionBlur" withInputParameters:@{@"inputRadius" : @10}];
    desImage = [srcImage imageByCompositingOverImage:backgroundImage];
    if (overlayImage) {
        desImage = [overlayImage imageByCompositingOverImage:desImage];
    }
    [[KKVideoCompositor sharedCIContext] render:desImage toCVPixelBuffer:outputPixels bounds:desImage.extent colorSpace:self.colorSpaceRef];
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

