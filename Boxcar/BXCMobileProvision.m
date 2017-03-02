/*
 
 Copyright (c) 2012-2017 ProcessOne SARL. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY PROCESSONE SARL ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL PROCESSONE SARL OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "BXCMobileProvision.h"

@implementation BXCMobileProvision

/*
  Analyze embedded.mobileprovision file to decide if we need to use production or sandbox for push notifications
  
  @return either @"production" or @"development"
 */
+ (NSString *)getAPNSMode {
    NSDictionary *mobileProvision = [self readMobileProvision];
    if (!mobileProvision) {
        // When in doubt use "production" to avoid causing loss of push in production is case of unexpected behaviour:
        return @"production";
    } else {
        NSDictionary *entitlements = [mobileProvision objectForKey:@"Entitlements"];
        if ([[entitlements objectForKey:@"get-task-allow"] boolValue]) {
            return @"development";
        } else {
            return @"production";
        }
    }
}

/* 
 Read the embedded.mobileprovision file embedded in the app and return a dictionary containing parsed
 content.
 
 @return an NSDictionary containing the extracted .plist content from embedded.mobile.provision file
 */
+ (NSDictionary*)readMobileProvision {
    NSString *mobileProvisionPath = [[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
    
    if (!mobileProvisionPath) {
        // We should find the file, but in case Apple change something just return nil
        return nil;
    }
    
    // NSISOLatin1 keeps the binary wrapper from being parsed as unicode and dropped as invalid
    //    NSString *binaryString = [NSString stringWithContentsOfFile:mobileProvisionPath encoding:NSISOLatin1StringEncoding error:nil];
    NSString *fullFileContent = [NSString stringWithContentsOfFile:mobileProvisionPath encoding:NSISOLatin1StringEncoding error:nil];
    if (!fullFileContent) { return nil; }
    
    NSScanner *scanner = [NSScanner scannerWithString:fullFileContent];
    if (![scanner scanUpToString:@"<plist" intoString:nil]) {  return nil; }
    
    NSString *extractedPlist;
    if (![scanner scanUpToString:@"</plist>" intoString:&extractedPlist]) {
        return nil;
    }
	
    NSData *plist = [[extractedPlist stringByAppendingString:@"</plist>"] dataUsingEncoding:NSISOLatin1StringEncoding];
    
    NSError *error;
    NSDictionary *mobileProvision = [NSPropertyListSerialization propertyListWithData:plist options:NSPropertyListImmutable format:nil error:&error];
	
    if (error) { return nil; }
	
    return mobileProvision;
}

@end
