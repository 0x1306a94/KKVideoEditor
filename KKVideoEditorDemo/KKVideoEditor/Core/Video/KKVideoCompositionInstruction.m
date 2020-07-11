//
//  KKVideoCompositionInstruction.m
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import "KKVideoCompositionInstruction.h"

#import <CoreImage/CIColor.h>

@implementation KKVideoCompositionInstruction

- (instancetype)initWithTimeRange:(CMTimeRange)timeRange {
    if (self == [super init]) {
        [self commonInit];
        _timeRange = timeRange;
    }
    return self;
}

- (void)commonInit {
    _timeRange                = kCMTimeRangeZero;
    self.backgroundColor      = [CIColor colorWithRed:0 green:0 blue:0];
    self.enablePostProcessing = YES;
    self.containsTweening     = NO;
    self.passthroughTrackID   = kCMPersistentTrackID_Invalid;
}
@end

