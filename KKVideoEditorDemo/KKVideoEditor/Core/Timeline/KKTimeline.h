//
//  KKTimeline.h
//  KKVideoEditorDemo
//
//  Created by king on 2020/7/15.
//

#import <Foundation/Foundation.h>

#import "KKVideoProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface KKTimeline : NSObject
@property (nonatomic, strong) NSArray<id<KKVideoProvider>> *videos;
@end

NS_ASSUME_NONNULL_END

