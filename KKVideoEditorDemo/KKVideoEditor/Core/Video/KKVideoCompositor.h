//
//  KKVideoCompositor.h
//  VideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVVideoCompositing.h>

NS_ASSUME_NONNULL_BEGIN

@interface KKVideoCompositor : NSObject <AVVideoCompositing>
@property (nonatomic, readonly, copy, nullable) NSDictionary<NSString *, id> *sourcePixelBufferAttributes;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *requiredPixelBufferAttributesForRenderContext;

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext;

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)asyncVideoCompositionRequest;
@end

NS_ASSUME_NONNULL_END

