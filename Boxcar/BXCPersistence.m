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

#import "BXCPersistence.h"
#import "BXCLogging.h"

@implementation BXCPersistence

#define kBXCFilename @"BXCSettings.bin"
#define kBXCFileKey  @"settings"

/* Path to the data file in the app's Documents directory */
+ (BXCSettings *)loadSettingsFromDisk {
    NSDictionary *rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:[self getFullPathForFile:kBXCFilename]];
    BXCSettings *settings = nil;
    id settingsData = [rootObject objectForKey:kBXCFileKey];
	
    if ([settingsData isKindOfClass:[BXCSettings class]]) {
		settings = settingsData;
	} else {
		ECLog(DebugChannel, @"Settings data class = %@", NSStringFromClass([settingsData class]));
	}
    
    if (settings == nil) {
        ECLog(DebugChannel, @"Settings == nil");
        settings = [[BXCSettings alloc] init];
    }
    return settings;
}

/* Save Settings on disk */
+ (void)saveSettingsToDisk:(BXCSettings *)settings {
    NSMutableDictionary *rootObject = [NSMutableDictionary dictionary];
	
    [rootObject setValue:settings forKey:kBXCFileKey];

    // Using a background task to free main thread faster
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(backgroundQueue, ^{
        [[NSKeyedArchiver archivedDataWithRootObject:rootObject] writeToFile:[self getFullPathForFile:kBXCFilename] atomically:YES];
    });
}

/* Path to the data file in the app's Documents directory */
+ (NSString *)getFullPathForFile:(NSString *)filename {
    NSArray *documentDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = nil;
    if (documentDir) {
        path = [documentDir objectAtIndex:0];
    }
    return [NSString stringWithFormat:@"%@/%@", path, filename];
}

@end
