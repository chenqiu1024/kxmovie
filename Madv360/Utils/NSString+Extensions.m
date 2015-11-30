//
//  NSString+Extensions.m
//  Madv360
//
//  Created by FutureBoy on 11/6/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#import "NSString+Extensions.h"

@implementation NSString (Extensions)

+ (NSString*) stringOfBundleFile : (NSString*)baseName
                         extName : (NSString*)extName {
    NSString* path = [[NSBundle mainBundle] pathForResource:baseName ofType:extName];
    NSString* ret = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    return ret;
}

+ (NSString*) stringWithJSONDictionary : (NSDictionary*)jsonDictionary {
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:jsonDictionary options:0 error:nil];
    NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

@end
