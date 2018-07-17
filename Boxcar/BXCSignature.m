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

#import "BXCSignature.h"
#import <CommonCrypto/CommonHMAC.h>

@implementation BXCSignature

/* Path must be absolute */
+ (NSString *)signatureWithMethod:(NSString *)method andHost:(NSString *)host andPath:(NSString *)path andBody:(NSString *)body andSecret:(NSString *)secret {
    NSString *tmpPath = [self removeTrailingSlashFrom:path];
    NSString *contentToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@", method, [host lowercaseString], tmpPath, body];

    const char *cKey = [secret cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [contentToSign cStringUsingEncoding:NSUTF8StringEncoding];

    if (cKey != NULL) {
        unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
        CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
        
        NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:CC_SHA1_DIGEST_LENGTH];
        
        NSString *signature = [NSString stringWithString:[HMAC description]];
        signature = [signature stringByReplacingOccurrencesOfString:@" " withString:@""];
        signature = [signature stringByReplacingOccurrencesOfString:@"<" withString:@""];
        signature = [signature stringByReplacingOccurrencesOfString:@">" withString:@""];
        
        return signature;
    }
    return @"";
}

/* Build the URL */
+ (NSURL *)buildSignedURLWithKey:(NSString *)key andSecret:(NSString *)secret forUrl:(NSURL *)url path:(NSString *)path method:(NSString *)method payload:(NSString *)payload {
    NSString *signature = [BXCSignature signatureWithMethod:method andHost:url.host andPath:path andBody:payload andSecret:secret];
    NSString *absoluteURL = [self removeTrailingSlashFrom:url.absoluteString];
    NSURL *tmpURL = [NSURL URLWithString:path relativeToURL:url];
    NSString *concat_char;
	
    if ([tmpURL query] != nil)
        concat_char = @"&";
    else
        concat_char = @"?";
    path = [path stringByAppendingFormat:@"%@clientkey=%@&signature=%@", concat_char, key, signature];
	
	return [NSURL URLWithString:[absoluteURL stringByAppendingString:path]];
}

/* Remove slash from given path */
+ (NSString *)removeTrailingSlashFrom:(NSString *)path {
    NSRange rng = [path rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:[path stringByReplacingOccurrencesOfString:@"/" withString:@""]] options:NSBackwardsSearch];
	
    return [path substringToIndex:rng.location + 1];
}

@end
