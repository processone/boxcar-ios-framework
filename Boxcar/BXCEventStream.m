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

#import "Boxcar.h"
#import "BXCEventStream.h"
#import "BXCSignature.h"
#import "BXCConstants.h"
#import "BXCMacros.h"
#import "BXCLogging.h"

@implementation BXCEventStream

NSMutableURLRequest *request;
NSError *currentError;

// TODO: Multi TCP packet parsing / buffering

/* Init with stream ID */
- (id)initWithStreamId:(NSString *)streamId {
    self = [super init];
    if (self) {
        _streamId = streamId;
        currentError = nil;
    }
    return (self);
}

/* Connect to the API */
- (void)connect {
    currentError = nil;
	
    if (self.streamId == nil) {
        ECLog(MainChannel, @"Missing Event Stream StreamId");
        return;
    }
    // DLog(@"Connecting with StreamId: %@", self.streamId);

    // To handle the reconnect case:
    if (self.connection) {
        [self.connection cancel];
        self.connection = nil;
    }

    NSString *path = [NSString stringWithFormat:@"/api/stream/%@/", self.streamId];
    // Signature:
    // TODO: Add missing expires for checking URL validity
    NSURL *serverURL = [[Boxcar sharedInstance] apiURL];
    NSURL *url = [BXCSignature buildSignedURLWithKey:[[Boxcar sharedInstance] clientKey] andSecret:[[Boxcar sharedInstance] clientSecret] forUrl:serverURL path:path method:@"GET" payload:@""];

    ECLog(DebugChannel, @"URL is %@", url.absoluteURL);
    request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"text/event-stream" forHTTPHeaderField:@"Accept"];
    [request setTimeoutInterval:60];
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.connection start];

    self.backgroundTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        // Cancel the connection
        if (self.connection) {
            [self.connection cancel];
            self.connection = nil;
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskID];
            self.backgroundTaskID = UIBackgroundTaskInvalid;
        }
    }];
}

#pragma mark NSURLConnectionDelegate

/* didReceiveResponse from stream */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    long code = [(NSHTTPURLResponse *)response statusCode];
	
    switch (code) {
        case 500:
            currentError = [NSError errorWithDomain:@"boxcar" code:code userInfo:@{NSLocalizedDescriptionKey:@"Event Stream: Server error"}];
            break;
        case 404:
            currentError = [NSError errorWithDomain:@"boxcar" code:code userInfo:@{NSLocalizedDescriptionKey:@"Event Stream: Not found"}];
            break;
    }
}

/* didReceiveData on event stream */
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSString *eventString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // DLog(@"Received: %@", eventString);

    // This is purely keep-alive content
    if ([eventString isEqualToString:@":\n"]) {
        ECLog(MainChannel, @"Still connected");
        return;
    }

    if (self.delegate == nil) {
        DLog(@"Warning: delegate is nil");
    } else {
        [self.delegate didReceiveEvent:[self parseEventData:eventString]];
    }
}

/* Stream didFailWithError */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    ECLog(MainChannel, @"Stream request error: %@, %@", error, error.userInfo);

    // We lost network / are not connected to internet.
    // Do not attempt to reconnect immediately.
    NSInteger code = [error code];
    if (code == kCFURLErrorNetworkConnectionLost || code == kCFURLErrorNotConnectedToInternet) {
        // Wait for a while and reconnects later.
        [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(connect) userInfo:nil repeats:NO];
        ECLog(MainChannel, @"Connection lost. Do not try to reconnect now");
    } else {
        ECLog(MainChannel, @"Other error: %@", error);
        // Cancel background task and reconnect
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskID];
        self.backgroundTaskID = UIBackgroundTaskInvalid;
        [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(connect) userInfo:nil repeats:NO];
    }
}

/* connectionDidFinishLoading */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	ECLog(DebugChannel, @"connectionDidFinishLoading");
	[[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskID];
	self.backgroundTaskID = UIBackgroundTaskInvalid;
	
	if (currentError && self.delegate) { [self.delegate didReceiveError:currentError]; }
}

/* Parse the event data */
- (NSString *)parseEventData:(NSString *)eventString {
    // TODO: We need to handle more parsing edge cases
    NSString *regexEventId = @"^id: (.*?)\n";
    NSError *error;
    NSUInteger options = 0;
    options = options | NSRegularExpressionDotMatchesLineSeparators;
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:regexEventId
                                                                            options:(NSRegularExpressionOptions) options error:&error];
    if (regexp == nil) ECLog(DebugChannel, @"Error making regex: %@", error );
    NSTextCheckingResult *match = [regexp firstMatchInString:eventString options:(NSMatchingOptions) 0
                                                       range:NSMakeRange(0, [eventString length])];
    NSRange range = [match rangeAtIndex:1];
    // TODO: Pass that ID to callback in an NSDictionary
    //NSString *idString = [eventString substringWithRange:range];
    NSString *dataString = [eventString substringFromIndex:range.location + range.length + 1];

    //DLog(@"Received id %@ and %@", idString, dataString);

    NSString *regexEventData = @"^data: (.*?)\n\n";
    regexp = [NSRegularExpression regularExpressionWithPattern:regexEventData
                                                       options:(NSRegularExpressionOptions) 0 error:&error];
    if (regexp == nil) ECLog(DebugChannel, @"Error making regex 2: %@", error );
    match = [regexp firstMatchInString:dataString options:(NSMatchingOptions) 0
                                 range:NSMakeRange(0, [dataString length])];
    range = [match rangeAtIndex:1];
    return [dataString substringWithRange:range];
}

@end
