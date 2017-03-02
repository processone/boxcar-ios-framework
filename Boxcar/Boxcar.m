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
#import "BXCSignature.h"
#import "BXCMacros.h"
#import "BXCPersistence.h"
#import "BXCJSON.h"
#import "BXCLogging.h"
#import "BXCJSONRequestOperation.h"
#import "BXCMobileProvision.h"

@import AdSupport.ASIdentifierManager;

@implementation Boxcar {
    BXCEventStream *eventStream;
}

@synthesize mode = _mode;

/* Always used the shared instance class method to access Boxcar instance singleton. */
+ (id)sharedInstance {
	static Boxcar *sharedInstance = nil;
	static dispatch_once_t token;
	
	dispatch_once(&token, ^{
		sharedInstance = [Boxcar new];
	});
	
	if (sharedInstance.settings == nil) { [sharedInstance loadDataFromDisk]; }
	
	return sharedInstance;
}

#warning setup is never called

/**
 *  Setup the Boxcar service assuming all options are read from BoxcarConfig.plist in application NSBundle.
 *
 *  @return YES if registration was handled properly by Boxcar framework.
**/
- (BOOL)setup {
    NSDictionary *options = [self readOptionsFromPlist];
	
    if ([options count] == 0) {
        [NSException raise:@"No option found" format:@"Using [Boxcar start] without BoxcarConfig.plist of with empty file"];
        return NO;
    }
	
	return [self startWithOptions:@{kBXC_CLIENT_KEY: options[@"clientKey"],
                                    kBXC_CLIENT_SECRET: options[@"clientSecret"],
                                    kBXC_API_URL: options[@"apiUrl"],
                                    kBXC_LOGGING: options[@"logging"]} error:nil];
}

/* Start services: Logging, Register Device, and set Mode */
- (void)startWithOptions:(NSDictionary *)options andMode:(NSString *)mode completionBlock:(BXCStartCompletionBlock)completionBlock {
  [[Boxcar sharedInstance] startWithOptions:options delegate:nil error:nil];
	[[Boxcar sharedInstance] setMode:mode];
	completionBlock(nil);
}

/* Start services: Logging & Register Device */
- (BOOL)startWithOptions:(NSDictionary *)options error:(NSError *)error {
  [[Boxcar sharedInstance] startWithOptions:options delegate:nil error:nil];
  return YES;
}

/* Start services: Logging, Register Device & Defines UNUserNotificationCenterDelegate */
- (BOOL)startWithOptions:(NSDictionary *)options delegate:(id <UNUserNotificationCenterDelegate>)delegate error:(NSError *)error {
    self.NCDelegate = delegate;
    self.clientKey = options[kBXC_CLIENT_KEY];
    self.clientSecret = options[kBXC_CLIENT_SECRET];
	
    if (options[kBXC_API_URL] && !self.apiURL) {
		NSString *APIUrl = options[kBXC_API_URL];
        self.apiURL = [NSURL URLWithString:APIUrl];
    } else {
        self.apiURL = [NSURL URLWithString:BXCDefaultAPIURL];
    }
    
    if (options[kBXC_LOGGING]) {
        [BXCLogging startup];
        [BXCLogging MainChannel:true];
    }
    
    // If push is enabled and we already registered, attempt to refresh the token:
	if ([self isPushEnabled]) {
        [self registerDevice];
	}
	
    // TODO: Check API URL to return error in case it is invalid
    // => Use precondition so that we give developer immediate feedback during development
    // Check that we have clientKey and secret => if not return NO and error.
    self.alreadyRegistering = NO;
    
    return YES;
}

/* Will return a dictionary filled with the Plist file content */
- (NSDictionary *)readOptionsFromPlist {
    NSString *path = [[NSBundle mainBundle] pathForResource: @"BoxcarConfig" ofType: @"plist"];

    return [[NSDictionary alloc] initWithContentsOfFile:path];
}

/* Will return the Remote Notification Options in the completion block */
- (void)extractRemoteNotificationFromLaunchOptions:(NSDictionary *)launchOptions completionBlock:(BXCExtractNotificationCompletionBlock)completionBlock {
	if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]) {
		completionBlock(launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]);
	} else {
		completionBlock(nil);
	}
}

/* Will return the Remote Notification Options */
- (NSDictionary *)extractRemoteNotificationFromLaunchOptions:(NSDictionary *)launchOptions {
    return launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
}

/* Will register a device on server if a device token is provided */
- (void)sendDeviceParameters {
    if (self.settings.deviceToken.length > 0) {
        [self registerOnServerWithToken:self.settings.deviceToken];
    } else {
        ECLog(MainChannel, @"Did not send parameters: No device token");
    }
}

/* Alias, Udid and mode properties are actually wrappers to settings.
   However, changing them will trigger proper server updating.
TODO:
 Maybe this should be change to a single KVO ?
 */
- (void)setAlias:(NSString *)alias {
    NSString *previousAlias = self.alias;

	[[self settings] setAlias:alias];
    
    if (![alias isEqualToString:previousAlias]) {
        [[self settings] setNeedUpdate:YES];
        [self saveDataToDisk];
    }
}

/* Will return the Alias */
- (NSString *)alias {
    return self.settings.alias;
}

/* tag management */
- (void)setTags:(NSArray *)tags {
    /* TODO: Check this is an array of strings */
    NSArray *previousTags = self.tags;

	[[self settings] setTags:tags];
    
    if (![tags isEqualToArray:previousTags]) {
        [[self settings] setNeedUpdate:YES];
        [self saveDataToDisk];
    }
}

/* Will return the tags */
- (NSArray *)tags {
    return self.settings.tags;
}

/* Set categories */
- (void)setCategories:(NSSet *)categories {
    _categories = categories;
	
    [self updateUserNotificationSettings];
}

/* Set deviceIdentifier to use advertising identifier */
- (void)useAdvertisingIdentifier:(BOOL)AdFlag {
    if (AdFlag) {
        if ([NSClassFromString(@"ASIdentifierManager") class]){
            [self setDeviceIdentifier:[[[NSClassFromString(@"ASIdentifierManager") sharedManager] advertisingIdentifier] UUIDString]];
        } else {
            ECLog(MainChannel, @"Please link your application against Apple AdSupport framework to use AdvertisingIdentifier");
        }
    } else {
        ECLog(DebugChannel, @"unset deviceIdentifier");
        [self setDeviceIdentifier:nil];
    }
	
    [[self settings] setNeedUpdate:YES];
    [self saveDataToDisk];
}

/* Will set the device identifier */
- (void)useVendorIdentifier:(BOOL)VendorFlag {
    if (VendorFlag) {
        [self setDeviceIdentifier:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    } else {
        ECLog(DebugChannel, @"unset deviceIdentifier");
        [self setDeviceIdentifier:nil];
    }
	
    [[self settings] setNeedUpdate:YES];
    [self saveDataToDisk];
}

/* Identifier can be any type of generated device ID.
   You can for example use identifierForVendor or advertisingIdentifier depending on your requirements
 */
- (void)setDeviceIdentifier:(NSString *)identifier {
    NSString *previousIdentifier = self.deviceIdentifier;
	
    [[self settings] setUdid:identifier];
    
    if (![identifier isEqualToString:previousIdentifier]) {
        [[self settings] setNeedUpdate:YES];
        [self saveDataToDisk];
    }
    
    if (identifier != nil && [identifier length] > 0) {
        // Reconnect eventstream if needed
        [eventStream setStreamId:identifier];
        if (![identifier isEqualToString:previousIdentifier])
            [self resetEventStream];
    }
}

/* Will return the device identifier */
- (NSString *)deviceIdentifier {
    return self.settings.udid;
}

/* Mode allow to decide which push server should be used (Sandbox or main server).
 It can be either @"development" or @"production"
 */
- (void)setMode:(NSString *)mode {
    if (!([mode isEqualToString:@"development"] || [mode isEqualToString:@"production"])) {
        ECLog(MainChannel, @"Cannot set mode to invalid value: %@", mode);
        return;
    }
    
    // DLog(@"My Mode is %@", self.settings.mode);
    NSString *previousMode = self.settings.mode;
    [[self settings] setMode:mode];

    if (![mode isEqualToString:previousMode]) {
        [[self settings] setNeedUpdate:YES];
        [self saveDataToDisk];
    }
}

/* Will return the mode */
- (NSString *)mode {
    return self.settings.mode;
}

#pragma mark - Push registration

/* Will do the actual registration for notification */
- (void)registerDevice {
    ECLog(DebugChannel, @"Registering for user notifications");
    UIApplication *application = [UIApplication sharedApplication];
	
    // Support for iOS 10
  if(SYSTEM_VERSION_GRATERTHAN_OR_EQUALTO(@"10.0")){
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self.NCDelegate;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error){
      if( !error ){
        [center setNotificationCategories:self.categories];
        [application registerForRemoteNotifications];
      }
    }];
  } else {
    // Support for iOS 9
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationType)(UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound) categories:self.categories];
        [application registerForRemoteNotifications];
        [application registerUserNotificationSettings:settings];
    } else {
      // Support for versions prior to iOS 9
        [application registerForRemoteNotificationTypes:(UIRemoteNotificationType)(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge)];
    }
  }
}

/* Only update the settings if we have a token */
- (void)updateUserNotificationSettings {
    if (self.settings.deviceToken.length > 0) {
        // iOS 8 specific. Primarily used to update categories
        UIApplication *application = [UIApplication sharedApplication];
        if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationType)(UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound) categories:self.categories];
            [application registerUserNotificationSettings:settings];
        }
    }
}

/* Will parse and set the token on server */
- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData* )deviceToken {
    NSString *stringToken = [[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    stringToken = [stringToken stringByReplacingOccurrencesOfString:@" " withString:@""];

    ECLog(MainChannel, @"Received Token: %@", stringToken);

    NSString *previousDeviceToken = self.settings.deviceToken;
    self.settings.deviceToken = stringToken;
    
    [self.settings updatePushState];
	
	if (![stringToken isEqualToString:previousDeviceToken] || self.settings.needUpdate) {
        [self saveDataToDisk];
        [self registerOnServerWithToken:stringToken];
    }
}

/* Handle Push Entitlement error */
- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    ECLog(MainChannel, @"Failed device register: %@", error.userInfo);
	
	if (error.code == 3000) {
        NSLog(@"Boxcar: Push Entitlement error. Usually, generating your provisioning profile again will solve the problem.");
    }
    
    // Should we reset the token here ?
    // Not sure it has a point updating the setting without token.
    if (self.settings.deviceToken.length > 0) {
        self.settings.deviceToken = nil;
        [[self settings] setNeedUpdate:YES];
        [self saveDataToDisk];
    }
}

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

/* Get options for notification in background */
- (void)trackNotification:(NSDictionary *)remoteNotif {
    [[Boxcar sharedInstance] trackNotification:remoteNotif inState:@"background"];
}

/* Get options for notification */
- (void)trackNotification:(NSDictionary *)remoteNotif forApplication:(UIApplication *)app {
    NSString *appState = @"active";
	
    if ([app applicationState] != UIApplicationStateActive) {
        appState = @"background";
    }
    [[Boxcar sharedInstance] trackNotification:remoteNotif inState:appState];
}

#pragma mark - Badge and notification clean-up

/* This method removes the notifications and keep the badge */
- (void)cleanNotifications {
	if ([self isUserBadgeAllowed]) {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:[UIApplication sharedApplication].applicationIconBadgeNumber];
    } else {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    }
}

/* This method removes the notifications and set badge to 0 (not displayed) */
- (void)cleanNotificationsAndBadge {
    [self resetServerBadge];
	
    if ([self isUserBadgeAllowed]) {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    }
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}

/* This method resets badge */
- (void)cleanBadge {
    [self resetServerBadge];
	
    if ([self isUserBadgeAllowed]) {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    }
}

/* Detect if the badge is allowed */
- (BOOL)isUserBadgeAllowed {
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)]) {
        // iOS 8
        UIUserNotificationSettings *currentSettings = [[UIApplication sharedApplication] currentUserNotificationSettings];
        return (currentSettings.types & UIUserNotificationTypeBadge);
    } else {
        // iOS 7: We can always set badge locally
        return YES;
    }
}

// The server tracks the number of badge on device
// We need to tell the server to reset
- (void)resetServerBadge {
    // We could reset badge only when badge on application is not already 0
    // (with following code)
    // if ([[UIApplication sharedApplication] applicationIconBadgeNumber] == 0) return;
    // However, always resetting the badge allow use to track when application was last used as well
    // This is useful for cleaning up database.
    
    NSString *deviceToken = self.settings.deviceToken;
    if (!deviceToken || [deviceToken length] == 0) {
        ECLog(DebugChannel, @"Skipping badge reset: no device token");
        return;
    }
 
    NSString *path = [NSString stringWithFormat:@"/api/reset_badge/%@", deviceToken];
    NSURL *url = [BXCSignature buildSignedURLWithKey:self.clientKey andSecret:self.clientSecret
                                              forUrl:self.apiURL path:path method:@"GET" payload:@""];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    // [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setTimeoutInterval:30];
    
    // TODO: Refactor HTTP result error logging:
    // DLog(@"Sending request on path: %@", path);
    ECLog(DebugChannel, @"Request: ResetBadge");
    BXCJSONRequestOperation *operation = [BXCJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *req, NSHTTPURLResponse *response, id JSON) {
        // Check for JSON error
        NSString *errorLabel = [JSON valueForKeyPath:@"error"];
        if (errorLabel) {
            ECLog(MainChannel, @"Request Failed with Error: %@", errorLabel);
        } else {
            //     DLog(@"Success");
        }
    } failure:^(NSURLRequest *req, NSHTTPURLResponse *response, NSError *error, id JSON) {
        // Error 404 can be safely ignored. It means we tried reset badge for a deleted device
        if ([response statusCode] != 404) {
            ECLog(MainChannel, @"Request Failed with Error: %@, %@", error, error.userInfo);
        }
    }];
    [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
    [operation start];
    request = nil;
    url = nil;
}

#pragma mark - Life cycle

/* Handle application notification */
- (void)applicationDidBecomeActive {
    [self registerOnServerWithToken:self.settings.deviceToken];
    DLog(@"Boxcar did become active");
    [self eventStreamConnect]; // Event Stream Reconnect
}

#pragma mark - HTTP Requests
/* Register Notification on Server */
- (void)registerOnServerWithToken:(NSString *)deviceToken {
    if (self.alreadyRegistering) {
        NSString *message = @"Skipping server upload. Already registering";
        [[NSNotificationCenter defaultCenter] postNotificationName:kBXC_DID_FAIL_TO_REGISTER_NOTIFICATION object:self userInfo:@{@"code":@400, @"message":message}];
        ECLog(DebugChannel, message);
        return;
    }
    
    if (!self.settings.needUpdate) {
        NSString *message = @"Skipping server upload. No need for update";
        [[NSNotificationCenter defaultCenter] postNotificationName:kBXC_DID_REGISTER_NOTIFICATION object:self userInfo:@{@"code":@201, @"message":message}];
        ECLog(DebugChannel, message);
        return;
    }
    
    if (!deviceToken || [deviceToken length] == 0) {
        NSString *message = @"Cannot registerOnServerWithToken: missing device token";
        [[NSNotificationCenter defaultCenter] postNotificationName:kBXC_DID_FAIL_TO_REGISTER_NOTIFICATION object:self userInfo:@{@"code":@500, @"message":message}];
        ECLog(MainChannel, message);
        return;
    }

    self.alreadyRegistering = YES;
    
    NSString *pushState = @"true";
    if (!self.settings.pushState) pushState = @"false";
    
    NSString *deviceName = [[UIDevice currentDevice] name];
    ECLog(DebugChannel, @"Device Name = %@", deviceName);
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            NULLIFNIL(self.settings.alias), @"alias",
                            NULLIFNIL([self mode]), @"mode",
                            NULLIFNIL(self.settings.udid), @"udid",
                            NULLIFNIL(deviceName), @"name",
                            NULLIFNIL(self.settings.appVersion), @"app_version",
                            NULLIFNIL(self.settings.osVersion), @"os_version",
                            NULLIFNIL(deviceName), @"name",
                            NULLIFNIL(self.tags), @"tags",
                            pushState, @"push",
                            nil];
    NSString *payload = [BXCJSON getRegisterPayloadWith:params];
    ECLog(DebugChannel, @"Sending device register payload: %@", payload);

    NSString *path = [NSString stringWithFormat:@"/api/device_tokens/%@", deviceToken];
    NSURL *url = [BXCSignature buildSignedURLWithKey:self.clientKey andSecret:self.clientSecret
                                              forUrl:self.apiURL path:path method:@"PUT" payload:payload];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[payload dataUsingEncoding:NSUTF8StringEncoding]];
    [request setTimeoutInterval:30];

    self.settings.needUpdate = YES; // This is to make sure we will recover in case the request never returns
    [self saveDataToDisk];
    Boxcar * __weak weakSelf = self;
    ECLog(DebugChannel, @"Request: registerWithToken");
    BXCJSONRequestOperation *operation = [BXCJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *req, NSHTTPURLResponse *response, id JSON) {
        weakSelf.alreadyRegistering = NO;

        // Check for JSON error
        NSString *errorLabel = [JSON valueForKeyPath:@"error"];
        if (errorLabel) {
            // Server returned an error, we will need to retry
            weakSelf.settings.needUpdate = YES;
            [weakSelf saveDataToDisk];
            NSString *message = [NSString stringWithFormat:@"Request Failed with Error: %@", errorLabel];
            [[NSNotificationCenter defaultCenter] postNotificationName:kBXC_DID_FAIL_TO_REGISTER_NOTIFICATION object:self userInfo:@{@"code":@501, @"message":message}];
            ECLog(MainChannel, message);
        } else {
            weakSelf.settings.needUpdate = NO;
            weakSelf.settings.lastServerUpdate = [NSDate date];
            [weakSelf saveDataToDisk];
            NSString *message = @"Register request success";
            [[NSNotificationCenter defaultCenter] postNotificationName:kBXC_DID_REGISTER_NOTIFICATION object:self userInfo:@{@"code":@200, @"message":message}];
            ECLog(DebugChannel, message);
        }
    } failure:^(NSURLRequest *req, NSHTTPURLResponse *response, NSError *error, id JSON) {
        weakSelf.alreadyRegistering = NO;
        weakSelf.settings.needUpdate = YES;
        [weakSelf saveDataToDisk];
        // TODO Schedule retry ?
        NSString *message = [NSString stringWithFormat: @"Register request Failed with Error: %@, %@", error, error.userInfo];
        [[NSNotificationCenter defaultCenter] postNotificationName:kBXC_DID_FAIL_TO_REGISTER_NOTIFICATION object:self userInfo:@{@"code":@502, @"message":message}];
        ECLog(MainChannel, message);
    }];
    [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
    [operation start];
    request = nil;
    url = nil;
}

/* Process notification */
- (void)trackNotification:(NSDictionary *)remoteNotif inState:(NSString *)state {
    if (remoteNotif) {
        if (self.settings.deviceToken) {
            NSString *pushId = [remoteNotif objectForKey:@"i"];
            NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                    NULLIFNIL(state), @"state",
                                    NULLIFNIL(pushId), @"id",
                                    nil];
            NSString *payload = [BXCJSON getReceivePayloadWith:params];
            NSString *path = [NSString stringWithFormat:@"/api/receive/%@", self.settings.deviceToken];
            NSURL *url = [BXCSignature buildSignedURLWithKey:self.clientKey andSecret:self.clientSecret forUrl:self.apiURL
                                                        path:path method:@"POST" payload:payload];

            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            [request setHTTPMethod:@"POST"];
            [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            [request setHTTPBody:[payload dataUsingEncoding:NSUTF8StringEncoding]];
            [request setTimeoutInterval:30];
    
            ECLog(DebugChannel, @"Request: trackNotification");
            BXCJSONRequestOperation *operation = [BXCJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *req, NSHTTPURLResponse *response, id JSON) {
                // Check for JSON error
                NSString *errorLabel = [JSON valueForKeyPath:@"error"];
                if (errorLabel) {
                    ECLog(MainChannel, @"Request Failed with Error: %@", errorLabel);
                } else {
                    //  DLog(@"Success");
                }
            } failure:^(NSURLRequest *req, NSHTTPURLResponse *response, NSError *error, id JSON) {
                ECLog(MainChannel, @"Request Failed with Error: %@, %@", error, error.userInfo);
            }];
            [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
            [operation start];
            request = nil;
            url = nil;
        }
    }
}

// TODO: Make sure we can replay device unregister when it fails
/**
 Unregister device from Boxcar Push server.
 
 This call deletes the device on the Boxcar server. After this call there is no more references to that device on the server and the device will not receive push anymore.
 
 This call is performing an HTTP request to Boxcar server, so network is required to unregister a device.
 
 @note When the call to the server is successful, local device data associated to Boxcar push are properly cleaned up.
 */
- (void)unregisterDevice {
    if (self.settings.deviceToken != nil) {
        NSString *path = [NSString stringWithFormat:@"/api/device_tokens/%@", self.settings.deviceToken];
        NSURL *url = [BXCSignature buildSignedURLWithKey:self.clientKey andSecret:self.clientSecret forUrl:self.apiURL path:path method:@"DELETE" payload:@""];

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"DELETE"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setTimeoutInterval:30];
    
        Boxcar * __weak weakSelf = self;
        ECLog(DebugChannel, @"Request: unregisterDevice");
        BXCJSONRequestOperation *operation = [BXCJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *req, NSHTTPURLResponse *response, id JSON) {
            // Check for JSON error
            NSString *errorLabel = [JSON valueForKeyPath:@"error"];
            if (errorLabel) {
                ECLog(MainChannel, @"Request Failed with Error: %@", errorLabel);
            } else {
                //  DLog(@"Success");
                weakSelf.settings.deviceToken = nil;
                weakSelf.settings.alias = nil;
                weakSelf.settings.udid = nil;
                weakSelf.settings.mode = nil;
                weakSelf.settings.appVersion = nil;
                weakSelf.settings.osVersion = nil;
                weakSelf.settings.lastServerUpdate = nil;
                weakSelf.settings.pushState= NO;
                weakSelf.settings.needUpdate = NO;
                [weakSelf saveDataToDisk];
            }
        } failure:^(NSURLRequest *req, NSHTTPURLResponse *response, NSError *error, id JSON) {
            ECLog(MainChannel, @"Request Failed with Error: %@, %@", error, error.userInfo);
        }];
        [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
        [operation start];
        request = nil;
        url = nil;
    }
}

/* RetrieveProjectTags */
- (void)retrieveProjectTagsWithBlock:(void (^)(NSArray *))resultBlock {
    NSString *path = @"/api/tags/";
    NSURL *url = [BXCSignature buildSignedURLWithKey:self.clientKey andSecret:self.clientSecret forUrl:self.apiURL
                                                path:path method:@"GET" payload:@""];
        
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setTimeoutInterval:30];
    
    ECLog(DebugChannel, @"Request: RetrieveProjectTags");
    BXCJSONRequestOperation *operation = [BXCJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *req, NSHTTPURLResponse *response, id JSON) {
            // Check for JSON error
            NSString *errorLabel = [JSON valueForKeyPath:@"error"];
            if (errorLabel) {
                ECLog(MainChannel, @"Request Failed with Error: %@", errorLabel);
            } else {
                // DLog(@"Success");
                NSArray *tags = [JSON valueForKeyPath:@"ok"];
                resultBlock(tags);
            }
        } failure:^(NSURLRequest *req, NSHTTPURLResponse *response, NSError *error, id JSON) {
            resultBlock(nil);
            ECLog(MainChannel, @"Request Failed with Error: %@, %@", error, error.userInfo);
        }];
    [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
    [operation start];
    request = nil;
    url = nil;
}

#pragma mark - Persistance

/* Save settings to disk */
- (void)saveDataToDisk {
    [BXCPersistence saveSettingsToDisk:self.settings];
}

/* Load settings to disk */
- (void)loadDataFromDisk {
    self.settings = [BXCPersistence loadSettingsFromDisk];
    
    // Check if there is update needed for some parameters (OSVersion, AppVersion, PushState)
    if ([self.settings tryUpdate])
        [self saveDataToDisk];
}

#pragma mark - EventStream

/* Connect to events stream with ID */
- (BOOL)connectToEventStreamWithId:(NSString *)streamId error:(NSError *__autoreleasing *)error {
    if (self.delegate != nil && streamId != nil &&![streamId isEqualToString:@""]) {
        self.streamId = streamId;
        [self initEventStream];
        [eventStream connect];
        return YES;
    } else {
        self.streamId = nil;
        [self disconnectFromEventStream];
        return NO;
    }
}

// TODO: explicit disconnect:
- (void)disconnectFromEventStream {
    
}

/* Will init the event stream and set the delegates */
- (void)initEventStream {
    if (!eventStream) {
        eventStream = [[BXCEventStream alloc] initWithStreamId:self.streamId];
    }
    [eventStream setDelegate:self];
}

/* Set or replace the delegates */
- (void)setDelegate:(id <BoxcarDelegate>)newDelegate {
    if (_delegate != newDelegate) {
        _delegate = newDelegate;
    }
}

/* reset the delegates */
- (void)resetEventStream {
    if ([self.streamId length] > 0) {
        [eventStream setStreamId:self.streamId];
        [eventStream setDelegate:self];
    }
    [self eventStreamConnect];
}

/* Connect the stream if we have a delegate and a streamID */
- (void)eventStreamConnect {
    if (self.delegate && [self.streamId length] > 0) {
        [eventStream connect];
    }
}

/* Forward event */
- (void)didReceiveEvent:(NSString *)event {
    [self.delegate didReceiveEvent:event];
}

/* Forward error */
- (void)didReceiveError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(didReceiveError:)]) {
        [self.delegate didReceiveError:error];
    }
}

#pragma mark - Helpers

/* For enabling debug channel */
- (void)dbm {
    [BXCLogging DebugChannel:YES];
}

@end
