//
//  KKVideoEditorPreviewView.m
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import "KKVideoEditorPreviewView.h"

#import <AVFoundation/AVPlayerLayer.h>

@implementation KKVideoEditorPreviewView

+ (Class)layerClass {
    return AVPlayerLayer.class;
}

- (AVPlayerLayer *)playerLayer {
    return (AVPlayerLayer *)self.layer;
}

- (void)setVideoGravity:(AVLayerVideoGravity)videoGravity {
    _videoGravity                   = videoGravity;
    [self playerLayer].videoGravity = videoGravity;
}

- (void)attachPlayer:(AVPlayer *)player {
    [self playerLayer].player = player;
}

@end

