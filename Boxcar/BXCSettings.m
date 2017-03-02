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

#import "BXCSettings.h"
#import "BXCMacros.h"
#import "BXCLogging.h"

@import UIKit;

@implementation BXCSettings

@synthesize mode = _mode;

#define kBXCDataVersion         @"dataVersion"
#define kBXCDeviceTokenKey      @"deviceToken"
#define kBXCAliasKey            @"alias"
#define kBXCUdidKey             @"udid"
#define kBXCModeKey             @"mode"
#define kBXCTagsKey             @"tags"
#define kBXCAppVersion          @"appVersion"
#define kBXCOSVersion           @"osVersion"
#define kBXCPushState           @"pushState"
#define kBXCNeedUpdate          @"needUpdate"
#define kBXCUpdateKey           @"lastUpdate"

#pragma mark NSCoding

/* initWithCoder */
- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (!self) return nil;
    
    self.dataVersion = [coder decodeObjectForKey:kBXCDataVersion];
    self.deviceToken = [coder decodeObjectForKey:kBXCDeviceTokenKey];
    self.alias = [coder decodeObjectForKey:kBXCAliasKey];
    self.udid = [coder decodeObjectForKey:kBXCUdidKey];
	_mode = [coder decodeObjectForKey:kBXCModeKey];
    self.tags = [coder decodeObjectForKey:kBXCTagsKey];
    self.appVersion = [coder decodeObjectForKey:kBXCAppVersion];
    self.osVersion = [coder decodeObjectForKey:kBXCOSVersion];
    _pushState  = [coder decodeBoolForKey:kBXCPushState];
    _needUpdate = [coder decodeBoolForKey:kBXCNeedUpdate];
    self.lastServerUpdate = [coder decodeObjectForKey:kBXCUpdateKey];
        
    return self;
}

/* encodeWithCoder */
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@"1" forKey:kBXCDataVersion];
    [coder encodeObject:self.deviceToken forKey:kBXCDeviceTokenKey];
    [coder encodeObject:self.alias forKey:kBXCAliasKey];
    [coder encodeObject:self.udid forKey:kBXCUdidKey];
    [coder encodeObject:self.mode forKey:kBXCModeKey];
    [coder encodeObject:self.tags forKey:kBXCTagsKey];
    [coder encodeObject:self.appVersion forKey:kBXCAppVersion];
    [coder encodeObject:self.osVersion forKey:kBXCOSVersion];
    [coder encodeBool:self.pushState forKey:kBXCPushState];
    [coder encodeBool:self.needUpdate forKey:kBXCNeedUpdate];
    [coder encodeObject:self.lastServerUpdate forKey:kBXCUpdateKey];
}

// TODO: Lower case passed mode
/* Set mode */
- (void)setMode:(NSString *)mode {
    // Only allow to set mode to acceptable values:
    if (mode && ([mode isEqualToString:@"development"] || [mode isEqualToString:@"production"])) {
        _mode = mode;
    } else  {
        _mode = @"development";
    }
}

/* Will return the current mode */
- (NSString *)mode {
    if ([_mode isEqualToString:@"development"] || [_mode isEqualToString:@"production"])
        return _mode;
    else
        return [self getDefaultMode];
}

/* Will set device token */
- (void)setDeviceToken:(NSString *)deviceToken {
    if (![deviceToken isEqualToString:_deviceToken])
        self.needUpdate = YES;

    _deviceToken = deviceToken;
}

/* Return if the server needs update or not */
- (BOOL)needUpdate {
    // Make sure we update at least once a day:
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

    if (self.lastServerUpdate != nil) {
        NSDateComponents *components = [calendar components:NSHourCalendarUnit fromDate:self.lastServerUpdate toDate:[NSDate date] options:NSCalendarMatchStrictly];
    
        if ([components hour] >= 24) {
            ECLog(DebugChannel, @"Time based update trigger (%ld)", (long)[components hour]);
            return YES;
        } else {
            ECLog(DebugChannel, @"No forced server update (%ld)", (long)[components hour]);
            return _needUpdate;
        }
    } else {
        return _needUpdate;
    }
}

/* Return the default mode */
- (NSString *)getDefaultMode {
#ifdef DEBUG
    return @"development";
#else
    return @"production";
#endif
}

/* Will try to update */
- (BOOL)tryUpdate {
    BOOL needSave = NO;
	
	if ([self needUpdateVersions]) {
        self.appVersion = [self retrieveAppVersion];
        self.osVersion = [self retrieveOSVersion];
        self.needUpdate = YES;
        needSave = YES;
    }
    
    BOOL currentPushState = [self isPushEnabled];
	
	if (currentPushState != self.pushState) {
        self.pushState = currentPushState;
        self.needUpdate = YES;
        needSave = YES;
    }

    return needSave;
}

/* Return if we need to update version */
- (BOOL)needUpdateVersions {
	if (self.osVersion == nil) { return YES; }
	if (self.appVersion == nil) { return YES; }
	
	if (![[self retrieveAppVersion] isEqualToString:self.appVersion]) { return YES; }
	if (![[self retrieveOSVersion] isEqualToString:self.osVersion]) { return YES; }

    return NO;
}

/* If push isn't enabled, need to update */
- (void)updatePushState {
    BOOL currentPushState = [self isPushEnabled];
	
    if (currentPushState != self.pushState) {
        self.pushState = currentPushState;
        self.needUpdate = YES;
    }
}

// TODO: Remove. Same function exist in Boxcar.m
/* Will return wether push is enable or not */
- (BOOL)isPushEnabled {
	UIApplication *application = [UIApplication sharedApplication];
	BOOL result = YES;
	
	if ([application respondsToSelector:@selector(currentUserNotificationSettings)]) {
		// iOS 8
		UIUserNotificationSettings *currentSettings = [application currentUserNotificationSettings];
		if (UIUserNotificationTypeNone == currentSettings.types)
			result = NO;
	} else {
		UIRemoteNotificationType types = [application enabledRemoteNotificationTypes];
		if (types == UIRemoteNotificationTypeNone)
			result = NO;
	}
	return result;
}

/* Will return the app version */
- (NSString *)retrieveAppVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
}

/* Will return the OS version */
- (NSString *)retrieveOSVersion {
    return [[UIDevice currentDevice] systemVersion];
}

@end
