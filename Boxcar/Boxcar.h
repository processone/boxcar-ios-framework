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

@import Foundation;

#import "BXCConstants.h"
#import "BXCSettings.h"
#import "BXCEventStream.h"

#import <UserNotifications/UserNotifications.h>

typedef NS_ENUM(NSUInteger, BXCClientNotificationMode) {
    BXCClientNotificationModeForeground,
    BXCClientNotificationModeBackground,
    BXCClientNotificationModeUserOpen
};

typedef NS_ENUM(NSUInteger, BXCAPNSService) {
    BXCAPNSServiceSandbox,
    BXCAPNSServiceProduction
};

/**
 You only need to implement the delegate method if you need to receive Boxcar inApp push events.
 This is not needed to receive notifications from Apple Push Notification Service.
 */
@protocol BoxcarDelegate <NSObject>
@optional
// For receiving in-app push directly from Boxcar platform:
- (void) didReceiveEvent:(NSString *)event;
- (void) didReceiveError:(NSError *)error;
@end

/**
 Boxcar is a singleton that encapsulate interface to Boxcar Push Platform.
 
 @copyright ProcessOne © 2012-2014
 
 The framework integrates two types of push notifications:
 1. Full support for *Apple Push Notification Service* (APNS).
 2. *InApp push*, which is a a push system that does not get through Apple Push. Its main advantage is that it does not requires the user to approve the reception of push messages through Apple mechanism. As such it can be fully used as a way to keep a realtime communication channel between Boxcar server and the application itself. The drawback is that it will only work while the application is running. This means that you also need to implement APNS as well if you want to notify the user after the 10 minutes the application is allowed to run in background.

 Using this class should be enough to fully control Push Service from your application.
 */

@interface Boxcar : NSObject <BXCEventStreamDelegate>

@property(nonatomic, weak) id <BoxcarDelegate> delegate;
@property(nonatomic, weak) id <UNUserNotificationCenterDelegate> NCDelegate;

@property(nonatomic, copy)   NSString *clientKey;
@property(nonatomic, copy)   NSString *clientSecret;
@property(nonatomic, strong) NSURL *apiURL;
@property(nonatomic, strong) BXCSettings *settings;

@property(nonatomic, copy)   NSString *alias;
@property(nonatomic, copy)   NSString *mode;
@property(nonatomic, strong) NSArray  *tags;
@property(nonatomic, copy)   NSString *deviceIdentifier;
@property(nonatomic, copy)   NSString *streamId;
@property(nonatomic, strong) NSSet *categories;

@property(nonatomic)         BOOL alreadyRegistering;

/**
 Always used the shared instance class method to access Boxcar instance singleton.
 */
+ (id)sharedInstance;

/**
 *  Setup the Boxcar service assuming all options are read from BoxcarConfig.plist in application NSBundle.
 *
 *  @return YES if registration was handled properly by Boxcar framework.
 */
- (BOOL)setup;

/**
*  Start the Boxcar service by directly providing options.
*
*  This routine is used to setup the Boxcar Push service (not the same as registering with APNS) and to prepare to receive notifications.
*
*  @warning You must start the Boxcar service from the applicationDidLoad:withOptions method in your App Delegate.
*
*  @param options NSDictionary containing valid options
*
*  @return YES if registration was handled properly by Boxcar framework.
*
<pre>
@textblock
NSDictionary *boxcarOptions = @{
 kBXC_CLIENT_KEY   : @"MYCLIENTKEY",
 kBXC_CLIENT_SECRET: @"MYCLIENTSECRET",
 kBXC_API_URL: @"https://boxcar-api.io",
 kBXC_LOGGING: @YES};
[[Boxcar sharedInstance] startWithOptions:boxcarOptions delegate:self error:nil];
@/textblock
</pre>
*/

typedef void (^BXCStartCompletionBlock)(NSError *error);
typedef void (^BXCExtractNotificationCompletionBlock)(NSDictionary *notification);

/* Start services: Logging, Register Device, and set Mode */
- (void)startWithOptions:(NSDictionary *)options andMode:(NSString *)mode completionBlock:(BXCStartCompletionBlock)completionBlock;

/* Start services: Logging & Register Device */
- (BOOL)startWithOptions:(NSDictionary *)options error:(NSError *)error;

/* Start services: Logging, Register Device & Defines UNUserNotificationCenterDelegate */
- (BOOL)startWithOptions:(NSDictionary *)options delegate:(id <UNUserNotificationCenterDelegate>)delegate error:(NSError *)error;

/* Will return the Remote Notification Options in the completion block */
- (void)extractRemoteNotificationFromLaunchOptions:(NSDictionary *)launchOptions completionBlock:(BXCExtractNotificationCompletionBlock)completionBlock;

/* Will return the Remote Notification Options */
- (NSDictionary *)extractRemoteNotificationFromLaunchOptions:(NSDictionary *)launchOptions;

/* To integrate in application life cycle: */
- (void)applicationDidBecomeActive;

/* Will parse and set the token on server */
- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData* )deviceToken;

/* Handle Push Entitlement error */
- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;

/**
 Associate a unique ID to device if advertising tracking is authorized by user.
 
 If your backend application requires being able to send push notification using a unique device id, you can use this method to associate that device to a unique device ID.

 The device ID can use any value. Possible values are:
 - VendorId: You can use Apple Vendor ID to get the same identifier for all your applications on the same device:

   ~~~{.m}
      NSString *vendorID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
      [[Boxcar sharedInstance] setIdentifier:vendorID];

      // Shortcut (recommended alternative):s
      [[Boxcar sharedInstance] useVendorIdentifier:YES];
   ~~~
 
 - AdvertisingIdentifier: If your application is displaying advertising (only in that case) and if your application is linked against AdSupport.framework, you can use Advertising identifier as unique ID:
 
   ~~~{.m}
      // All those calls require your app to be linked with AdSupport.framework
      NSString *advertiserID = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
      [[Boxcar sharedInstance] setIdentifier:advertiserID];
 
      // Shortcut (recommended alternative):
      [[Boxcar sharedInstance] useAdvertisingIdentifier:YES];
   ~~~
 */
- (void)useAdvertisingIdentifier:(BOOL)AdFlag;
- (void)useVendorIdentifier:(BOOL)AdFlag;

/* 
 This method is use to trigger the device registration and the popup to ask user if he wants to allow push notification from application.
 The user will only be asked once. The actual configuration can be change in iOS notification center settings for that application.
 */
- (void)registerDevice;

/**
 Return the state of the push configuration from Notification Center preference for a given user
 
 It returns true if either badge, alert or sound is enabled. If all is disabled the method will return false. It means the user will not
 receive anything and no code execution will be triggered in the application.
*/
- (BOOL)isPushEnabled;

/**
 Upload the setting changes to Boxcar server.
 
 Boxcar SDK will always retry in subsequent launches of the application until the registration is properly done.
 However, you can subscribe to specific notifications if your application need to know when the registration has been performed.
 
    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:\@selector(boxcarRegisterNotification:)
                                                  name:kBXC_DID_REGISTER_NOTIFICATION
                                                object:nil];
 
 There is a specific notification for failure:
 
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:\@selector(boxcarRegisterNotification:)
                                                 name:kBXC_DID_FAIL_TO_REGISTER_NOTIFICATION
                                               object:nil];
 
 This is not a permanent failure, so registration will be retried. It means you can receive more than one notification for a registration call (possibly several failures before one success).
 
 Note: Those notification are NSNotification instance. This is internal code state change events. They have nothing to do with push notifications.
 
 The userinfo dictionary from the NSNotification object typically contains two keys @"code" and @"message" which give extra information on the notification status. For failure, it
 gives an idea of the reason of the failure to process the call.
 */
- (void)sendDeviceParameters;

/* Get options for notification in background */
- (void)trackNotification:(NSDictionary *)remoteNotif;

/* Get options for notification */
- (void)trackNotification:(NSDictionary *)remoteNotif forApplication:(UIApplication *)app;

/* This method removes the notifications and keep the badge */
- (void)cleanNotifications;

/* This method removes the notifications and set badge to 0 (not displayed) */
- (void)cleanNotificationsAndBadge;

/* This method resets badge */
- (void)cleanBadge;

/**
 Unregister device from Boxcar Push server.
 
 This call deletes the device on the Boxcar server. After this call there is no more references to that device on the server and the device will not receive push anymore.
 
 This call is performing an HTTP request to Boxcar server, so network is required to unregister a device.
 
 @note When the call to the server is successful, local device data associated to Boxcar push are properly cleaned up.
 */
- (void)unregisterDevice;

/* Tag management */
- (void)retrieveProjectTagsWithBlock:(void (^)(NSArray *))resultBlock;
// @property(nonatomic, strong) NSArray *tags;
// BOOL setTags: error:? 


/* InApp Realtime event distribution */
- (BOOL)connectToEventStreamWithId:(NSString *)streamId error:(NSError **)error;
- (void)disconnectFromEventStream;

/* Put Framework in debug mode */
- (void)dbm;

@end
