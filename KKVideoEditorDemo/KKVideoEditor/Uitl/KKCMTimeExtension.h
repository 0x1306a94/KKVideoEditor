//
//  KKCMTimeExtension.h
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import <CoreMedia/CMTime.h>
#import <CoreMedia/CMTimeRange.h>

CM_INLINE Float64 kk_factorForTimeInRange(CMTime time, CMTimeRange range) {
	CMTime elapsed = CMTimeSubtract(time, range.start);
	return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration);
}

static const CMTimeScale kkVideoEditorCommonTimeScale = 600;

