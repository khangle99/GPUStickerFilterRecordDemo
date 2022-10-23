//
//  UIImageView+SK.h
//  showker
//
//  Created by cain on 14-5-21.
//  Copyright (c) 2014年 cain. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NSDictionary (DeepCopy)
- (NSMutableDictionary *) mutableDeepCopy;
@end

@interface NSArray (DeepCopy)
- (NSMutableArray *)mutableDeepCopy;
@end

@interface NSNumber (DeepCopy)
- (id)mutableDeepCopy;
@end
