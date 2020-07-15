//
//  KKVideoCompositionTrackProvider.h
//  KKVideoEditorDemo
//
//  Created by king on 2020/7/15.
//

#import <CoreMedia/CMBase.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AVMutableComposition;
@class AVCompositionTrack;

@protocol KKVideoCompositionTrackProvider <NSObject>
@required
- (NSInteger)numberOfVideoTracks;
- (AVCompositionTrack *)videoCompositionTrack:(AVMutableComposition *)composition atIndex:(NSInteger)atIndex preferredTrackID:(CMPersistentTrackID)preferredTrackID;
@end

NS_ASSUME_NONNULL_END

