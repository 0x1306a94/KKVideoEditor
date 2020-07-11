//
//  KKVideoEditorFactory.h
//  KKVideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import <CoreGraphics/CGBase.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CIColor;

@interface KKVideoEditorFactory : NSObject

@end

FOUNDATION_EXTERN CGFloat kk_interpolationFrom(CGFloat from, CGFloat to, CGFloat percent);

FOUNDATION_EXTERN CIColor *kk_interpolationCIColorFrom(CIColor *fromColor, CIColor *toColor, CGFloat percent);

NS_ASSUME_NONNULL_END

