//
//  KKVideoEditorPreviewView.h
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVAnimation.h>

NS_ASSUME_NONNULL_BEGIN

@class AVPlayer;

@interface KKVideoEditorPreviewView : UIView
@property (nonatomic, copy) AVLayerVideoGravity videoGravity;
- (void)attachPlayer:(AVPlayer *)player;

@end

NS_ASSUME_NONNULL_END

