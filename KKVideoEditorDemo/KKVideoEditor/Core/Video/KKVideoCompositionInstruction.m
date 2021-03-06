//
//  KKVideoCompositionInstruction.m
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import "KKVideoCompositionInstruction.h"

#import <CoreImage/CIColor.h>

@implementation KKVideoCompositionInstruction

- (instancetype)initWithPassthroughTrackID:(CMPersistentTrackID)passthroughTrackID timeRange:(CMTimeRange)timeRange {
	self = [super init];
	if (self) {
		_passthroughTrackID     = passthroughTrackID;
		_timeRange              = timeRange;
		_requiredSourceTrackIDs = @[];
		_containsTweening       = NO;
		_enablePostProcessing   = NO;
		[self commonInit];
	}
	return self;
}

- (instancetype)initWithSourceTrackIDs:(NSArray<NSValue *> *)sourceTrackIDs timeRange:(CMTimeRange)timeRange {
	self = [super init];
	if (self) {
		_requiredSourceTrackIDs = sourceTrackIDs;
		_timeRange              = timeRange;
		_passthroughTrackID     = kCMPersistentTrackID_Invalid;
		_containsTweening       = YES;
		_enablePostProcessing   = NO;
		[self commonInit];
	}
	return self;
}

- (void)commonInit {
	_backgroundColor = [CIColor colorWithRed:0 green:0 blue:0];
}

- (NSString *)debugDescription {
	return [NSString stringWithFormat:@"<%@: %p {{%lld/%d = %.03f}, {%lld/%d = %.03f}}>",
	                                  NSStringFromClass(self.class),
	                                  self,
	                                  self.timeRange.start.value,
	                                  self.timeRange.start.timescale,
	                                  CMTimeGetSeconds(self.timeRange.start),
	                                  self.timeRange.duration.value,
	                                  self.timeRange.duration.timescale,
	                                  CMTimeGetSeconds(self.timeRange.duration)];
}
@end

