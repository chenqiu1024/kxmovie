//
//  UIViewController+Extensions.m
//  Madv360_v1
//
//  Created by FutureBoy on 11/23/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#import "UIViewController+Extensions.h"

@implementation UIViewController (Extensions)

+ (void)setPresentationStyleForSelfController:(UIViewController *)selfController presentingController:(UIViewController *)presentingController
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
    {
        presentingController.providesPresentationContextTransitionStyle = YES;
        presentingController.definesPresentationContext = YES;
        
        [presentingController setModalPresentationStyle:UIModalPresentationOverCurrentContext];
    }
    else
    {
        [selfController setModalPresentationStyle:UIModalPresentationCurrentContext];
        [selfController.navigationController setModalPresentationStyle:UIModalPresentationCurrentContext];
    }
}

- (void)setPresentationStyle:(UIViewController *)presentingController {
    [self.class setPresentationStyleForSelfController:self presentingController:presentingController];
}

@end
