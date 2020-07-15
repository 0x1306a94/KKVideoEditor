//
//  KKVideoProvider.h
//  KKVideoEditorDemo
//
//  Created by king on 2020/7/15.
//

#import "KKCompositionTimeRangeProvider.h"
#import "KKVideoCompositionProvider.h"
#import "KKVideoCompositionTrackProvider.h"

NS_ASSUME_NONNULL_BEGIN

@protocol KKVideoProvider <KKCompositionTimeRangeProvider, KKVideoCompositionTrackProvider, KKVideoCompositionProvider>

@end

NS_ASSUME_NONNULL_END

