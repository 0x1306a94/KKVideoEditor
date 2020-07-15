//
//  KKTrackItem.h
//  KKVideoEditorDemo
//
//  Created by king on 2020/7/15.
//

#import "KKVideoProvider.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KKTrackItem : NSObject <KKVideoProvider>
#pragma mark - KKCompositionTimeRangeProvider
@property (nonatomic, assign) CMTime startTime;
@property (nonatomic, assign, readonly) CMTime duration;
@property (nonatomic, assign, readonly) CMTimeRange timeRange;

#pragma mark - KKVideoCompositionTrackProvider
- (NSInteger)numberOfVideoTracks;
- (AVCompositionTrack *)videoCompositionTrack:(AVMutableComposition *)composition atIndex:(NSInteger)atIndex preferredTrackID:(CMPersistentTrackID)preferredTrackID;

#pragma mark - KKVideoCompositionProvider
- (CIImage *)applyEffect:(CIImage *)sourceImage atTime:(CMTime)atTime renderSize:(CGSize)renderSize;
@end

NS_ASSUME_NONNULL_END

