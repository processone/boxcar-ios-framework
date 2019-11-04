//
//  BXCUtilities.m
//  Boxcar
//
//  Created by Antonin on 31/10/2019.
//  Copyright © 2019 ProcessOne. All rights reserved.
//

#import "BXCUtilities.h"

@implementation BXCUtilities

/* return formated bytes from NSData as string ( previously [NSData description] ) */
+ (NSString * _Nullable)formatedBytesFromDatas:(NSData * _Nullable)datas {
    if(datas == nil){
        return nil;
    }
    NSUInteger length = datas.length;
    if (length == 0) {
        return nil;
    }
    const unsigned char *buffer = datas.bytes;
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(length * 2)];
    for (int i = 0; i < length; ++i) {
        [hexString appendFormat:@"%02x", buffer[i]];
    }
    return [hexString copy];
}

@end
