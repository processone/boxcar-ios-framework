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

#import "BXCLogging.h"

ECDefineLogChannel(MainChannel)
ECDefineLogChannel(DebugChannel)

@implementation BXCLogging

/* initialise log manager (with default handler for NSLog) */
+ (void)startup {
    ECLogManager* lm = [ECLogManager sharedInstance];
    [lm startup];
    // No logging as default
    [lm disableAllChannels];
}

/* Enable or not MainChanel */
+ (void)MainChannel:(BOOL)enabled {
    if (enabled)
        ECEnableChannel(MainChannel);
    else
        ECDisableChannel(MainChannel);
}

/* Enable or not DebugChanel */
+ (void)DebugChannel:(BOOL)enabled {
    if (enabled)
        ECEnableChannel(DebugChannel);
    else
        ECDisableChannel(DebugChannel);
}

@end
