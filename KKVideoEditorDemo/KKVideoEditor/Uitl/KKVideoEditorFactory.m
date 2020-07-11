//
//  KKVideoEditorFactory.m
//  KKVideoEditorDemo
//
//  Created by king on 2020/7/11.
//

#import "KKVideoEditorFactory.h"

#import <CoreImage/CIColor.h>

@implementation KKVideoEditorFactory

@end

CGFloat kk_interpolationFrom(CGFloat from, CGFloat to, CGFloat percent) {
    percent = MAX(0, MIN(1, percent));
    return from + (to - from) * percent;
}

CIColor *kk_interpolationCIColorFrom(CIColor *fromColor, CIColor *toColor, CGFloat percent) {
    CGFloat red   = kk_interpolationFrom(fromColor.red, toColor.red, percent);
    CGFloat green = kk_interpolationFrom(fromColor.green, toColor.green, percent);
    CGFloat blue  = kk_interpolationFrom(fromColor.blue, toColor.blue, percent);
    CGFloat alpha = kk_interpolationFrom(fromColor.alpha, toColor.alpha, percent);
    return [CIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

