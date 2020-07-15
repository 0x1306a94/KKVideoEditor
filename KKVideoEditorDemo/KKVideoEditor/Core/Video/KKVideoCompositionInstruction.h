//
//  KKVideoCompositionInstruction.h
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVVideoCompositing.h>
#import <AVFoundation/AVVideoComposition.h>

NS_ASSUME_NONNULL_BEGIN

@class CIColor;
@class CIImage;

@interface KKVideoCompositionInstruction : NSObject <AVVideoCompositionInstruction>
@property (nonatomic, strong) CIColor *backgroundColor;
@property (nonatomic, assign, readonly) CMTimeRange timeRange;
@property (nonatomic, assign) BOOL enablePostProcessing;
@property (nonatomic, assign) BOOL containsTweening;
@property (nonatomic, strong, nullable) NSArray<NSValue *> *requiredSourceTrackIDs;
@property (nonatomic, assign) CMPersistentTrackID passthroughTrackID;

@property (nonatomic, copy) NSString *filterName;
@property (nonatomic, copy) CIImage *overlayImage;

@property (nonatomic, copy) NSArray<AVVideoCompositionLayerInstruction *> *layerInstructions;

@property (nonatomic, assign) CMTimeRange transitionRange;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithPassthroughTrackID:(CMPersistentTrackID)passthroughTrackID timeRange:(CMTimeRange)timeRange NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithSourceTrackIDs:(NSArray<NSValue *> *)sourceTrackIDs timeRange:(CMTimeRange)timeRange NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END

