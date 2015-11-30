//
//  NSString+Extensions.h
//  Madv360
//
//  Created by FutureBoy on 11/6/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Extensions)

+ (NSString*) stringOfBundleFile : (NSString*)baseName
                         extName : (NSString*)extName;

+ (NSString*) stringWithJSONDictionary : (NSDictionary*)jsonDictionary;

@end
