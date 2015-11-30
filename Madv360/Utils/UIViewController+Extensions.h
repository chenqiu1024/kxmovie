//
//  UIViewController+Extensions.h
//  Madv360_v1
//
//  Created by FutureBoy on 11/23/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (Extensions)

/**Presnet as Popup Model View*/
+ (void)setPresentationStyleForSelfController:(UIViewController *)selfController presentingController:(UIViewController *)presentingController;

- (void)setPresentationStyle:(UIViewController *)presentingController;

@end
