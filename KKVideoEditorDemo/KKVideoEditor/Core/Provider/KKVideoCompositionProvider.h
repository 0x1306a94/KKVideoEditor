//
//  KKVideoCompositionProvider.h
//  KKVideoEditorDemo
//
//  Created by king on 2020/7/15.
//

#import <CoreGraphics/CGGeometry.h>
#import <CoreMedia/CMTime.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CIImage;

@protocol KKVideoCompositionProvider <NSObject>
@required
- (CIImage *)applyEffect:(CIImage *)sourceImage atTime:(CMTime)atTime renderSize:(CGSize)renderSize;
@end

NS_ASSUME_NONNULL_END

