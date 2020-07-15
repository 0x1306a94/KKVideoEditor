//
//  KKCompositionTimeRangeProvider.h
//  KKVideoEditorDemo
//
//  Created by king on 2020/7/15.
//

#import <Foundation/Foundation.h>

#import <CoreMedia/CMTime.h>
#import <CoreMedia/CMTimeRange.h>

NS_ASSUME_NONNULL_BEGIN

@protocol KKCompositionTimeRangeProvider <NSObject>
@required
@property (nonatomic, assign) CMTime startTime;
@property (nonatomic, assign, readonly) CMTime duration;
@property (nonatomic, assign, readonly) CMTimeRange timeRange;
@end

NS_ASSUME_NONNULL_END

