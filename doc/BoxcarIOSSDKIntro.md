# Boxcar Push Service - iOS SDK introduction - v1.0.9

## Configuration

Creating push environment using Apple tools is not easy and is full of pitfalls. In case of trouble, do not hesitate to contact ProcessOne support for Boxcar Push Service by sending a mail to [support@boxcar.uservoice.com][1].

### Registering

#### Certificate creation

To register an iOS client on Boxcar Push Service, you need to provide Apple push certificates for development and production version.
It is a .pem file without password protection. you can generate it from any of the following:
* .p12 keychain export
* .cer file coming from Apple Provisioning portal

Follow Apple documentation, you can find on: 
This will allow you to export a .p12 file from Apple Keychain (without password): [Provisioning and Development][2].

Sandbox [^1] and production passwordless certificates .pem can be then upload on Boxcar Push Service. 

#### Client creation on Boxcar Push Console

With one or two certificates ready, as a Boxcar organisation owner, you can create your iOS application in the relevant project on Boxcar Push Console and upload one or two certificates.

1. Navigate to your project (Example: P1Framework).
![][image-1]
2. Select the client list.
3. Click on the button to add a client
4. Enter client name and type (iOS).
5. Upload your certificates.

### SDK Parameters

To set up the Boxcar iOS SDK, you will need the following parameters:
* __ClientKey__ and __ClientSecret__: This is two strings embedded in your client application. They allow your application to register a device, notify the server about opened notifications. They are use to sign your request and "authenticate" you 
* __APIURL__: This is the endpoint to use for your organisation for all API calls.

## Using the Boxcar iOS SDK

### Frameworks
To use the Boxcar SDK in your project, you need to drag and drop the provided Boxcar.framework directory in your Frameworks group in your XCode project:
![]()

You also need to activate the AdSupport Framework as optional:
![]()
This AdSupport framework is only used if you want to use the optional _AdvertisingIdentifier_ on iOS 6 and thus is optional.

### Step by step integration guide

#### AppDelegate: - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions

##### Configure and start the Boxcar framework

You can prepare a NSDictionary, that contains the relevant options:
	NSDictionary *boxcarOptions = @{ kBXC_CLIENT_KEY   : @"rqet2tBuxHXzzrJmhyAfwPIyxHX6_e7lkRysPj7MXBzEfVmI-JvAvHxfYvBkZOR9",
	                                 kBXC_CLIENT_SECRET: @"t5DWCxESkq_F6bVgpTxEroy7fs4XT4SS1pjXIeH5zhifRs4BOvKW2C4yjhVUdNee",
	                                 kBXC_API_URL:       @"https://yellow2.process-one.net",
	                                 kBXC_LOGGING: @YES };
And pass it to Boxcar instance *startWithOptions:error: method*:
	[[Boxcar sharedInstance] startWithOptions:boxcarOptions error:nil];

Mandatory parameters are:
* **kBXC\_CLIENT\_KEY**: Your application client key on Boxcar Push console.
* ** kBXC\_CLIENT\_SECRET**: Your application client sevret on Boxcar Push console.
* ** kBXC\_API\_URL**: API endpoint URL.
Logging can be enable / disable with the boolean parameter:
* ** kBXC\_LOGGING**: This is a boolean. We recommand you set it to *YES* while you develop and to *NO* in your Apple AppStore build (This is important to avoid you client key appearing in the logs).

##### Define your push mode

If you upload your application to your device through your cable during development phase, you will have to use the sandbox push certificate to receive push notifications. This is done by using __"development"__ mode.
If you are distributing your application (through adhoc mode, App Store or enterprise), then you have to set you application in __"production"__ mode.

If your application configuration define DEBUG only in development, then a typical pattern to use is:
	# ifdef DEBUG
	[[Boxcar sharedInstance] setMode:@"development"];  // = sandbox
	# else
	[[Boxcar sharedInstance] setMode:@"production"];
	# endif

##### (Optional) Enable the use of advertiserIdentifier

The use of that identifier is disabled as a default. If you want to associate that advertiserIdentifier on device registration on the server, you have to enable it explicitely:
	[[Boxcar sharedInstance] useAdvertisingIdentifier:YES];

With that identifier you can know that the same device is used by several of your applications and can use that information for marketing purpose.

##### Perform launch step house keeping tasks

When launching the app, you have to:
- Extract notification from AppDelegate launchOptions to see if your application was started by opening a push notifcation:
		NSDictionary *remoteNotif = [[Boxcar sharedInstance] extractRemoteNotificationFromLaunchOptions:launchOptions];
- Make sure you gather accurate statistics on opened notifications on the server, by calling the trackNotification: method:
		[[Boxcar sharedInstance] trackNotification:remoteNotif];
- Clean and reset badge and notification center on appliation launch:
		[[Boxcar sharedInstance] cleanNotificationsAndBadge];
- If there is actually a notification, you might want to pass it to a central method in your code that will process it:
	if (remoteNotif)
		   [self myProcessNotification:remoteNotif];

#### AppDelegate: - (void)applicationWillEnterForeground:(UIApplication *)application *
##### House keeping

It is usually a good idea to clean / reset notification and badge here:
	[[Boxcar sharedInstance] cleanNotificationsAndBadge];

#### AppDelegate: - (void)applicationDidBecomeActive:(UIApplication *)application *
##### Restart paused process
You need to restart any tasks that were paused (or not yet started) while the application was inactive:
	[[Boxcar sharedInstance] applicationDidBecomeActive];

#### AppDelegate: - (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken

This method is called when the device successfully registered on the Apple Push Service. You have to pass that information to Boxcar SDK with the following command:
	[[Boxcar sharedInstance] didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];

#### AppDelegate: - (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)error

This method is called when the application could not get a push token from Apple. You need to pass that info as well to Boxcar SDK:
	[[Boxcar sharedInstance] didFailToRegisterForRemoteNotificationsWithError:error];

#### AppDelegate: - (void)application:(UIApplication *)app didReceiveRemoteNotification:(NSDictionary *)remoteNotif

This is the second way an application can receive a notification.

##### House keeping
You have to do some house keeping as well:
- Generate proper server-side open rate statistics:
		[[Boxcar sharedInstance] trackNotification:remoteNotif forApplication:app];
- Reset the badge and notification list in notification center:
		[[Boxcar sharedInstance] cleanNotificationsAndBadge];

You can choose to do all your house keeping in your central push processing method if you prefer. We like to make it explicit in both paths that a notification can take, but you can adapt our approach to your own way.

##### Call your central processing method:
You should call your central processing method:
	     [self myProcessNotification:remoteNotif];

##### AppDelegate: Custom processing method

As a notification can take two different paths in the appDelegate code, it is a good idea to process it in a common method. Here is an example of what you could do with the notification dictionary in your code. This is a good example on how to manipulate and extract content from the notification.

	- (void)myProcessNotification:(NSDictionary *)remoteNotif {
	    // aps is second level structure
	    NSDictionary *APS = [remoteNotif objectForKey:@"aps"];
	    [self myNotifLog:APS forKey:@"alert"];
	    [self myNotifLog:APS forKey:@"sound"];
	
	    // Custom fields
	    // For example the id can be used to open the proper place / object inside the application
	    [self myNotifLog:remoteNotif forKey:@"mymetadata"];
	
	    // Example on how to process notification somewhere else
	    [[NSNotificationCenter defaultCenter] postNotificationName:@"pushNotification" object:nil userInfo:remoteNotif];
	}

See Push Application demo for details.

#### Other needed calls
To support Apple Push Notifications you need a few more Boxcar SDK method call to place in your application.

##### setAlias
Aliases are used in Boxcar Push Service to notify the users without knowing their device tokens [^2]. To target a given user from the Boxcar Push Console, you need to use an alternative id that is known by developer backend system. This is the alias.

You can set the alias with the following command:
	[[Boxcar sharedInstance] setAlias:aliasString];

This method call has to be placed in a code path where you know that the alias has been certified in a given way. If you use a userid, email, login, it has to have been validated as it is considered trusted by Boxcar Push Service[^3]. If you cannot trust that ID in your application, then consider using advertisingIdentifier.

##### advertisingIdentifier
If you have no trusted identifier to use, you can alternatively use AdvertiserIdentifier. This is a random id that you can pass to your backend, that will allow you to target a given user without having to manage device tokens.

If you enabled use of AdvertisingIdentifier with the following call:
	[[Boxcar sharedInstance] useAdvertisingIdentifier:YES];
you can retrieve it when you need it with the following method:
	[[Boxcar sharedInstance] advertisingIdentifier];

##### sendDeviceParameters method
To make sure we do not make a request on every change of parameters, you have to explicitely tell the framework that you are done changing parameters (like *setAlias* or *setTags*, for example).
So, after change to parameters, do not forget to call *sendDeviceParameters* when you are done with all the changes:
	 [[Boxcar sharedInstance] sendDeviceParameters];
 It means you set up all your parameters and are ready to send the data to the server. You can call it during app startup or in another place (for example in your settings controller) as update is only performed, if data have changed since the last update.

##### registerDevice method
When you have everything in place and think it is a good moment to enable push. Here is the method call:

	[[Boxcar sharedInstance] registerDevice];

You need to call it only once when you think the user is ready to enable the push, understand the benefit and is likely to accept it when iOS will ask for authorization. It thus thus not a good idea to ask right on application launch. Do not forget that if user reject the push request, changing his mind can be quite complex: It will have to go into iOS notification settings directly and will manually configure the notifications for the application.

Note that the SDK takes care of refreshing / updating the tokens and the server automatically for you.

##### (optional) retrieveProjectTags
When you want to set up the channels that are available for subscription for a given project, you can call the method retrieveProjectTags.
	[[Boxcar sharedInstance] retrieveProjectTags];

It returns an NSArray of NSString objects, containing all the available tag names (all lowercase).
If you want to present those tags in a multilingual interface, we expect that you will pass those tags name as key for your application translation file.

Note: you can embed the list of tags directly on the device. Retrieving the list of project tags is optional, as tags will even be created on the fly if they do not exist yet on your project.

##### setTags:error:
If you want to update your tag subscriptions, you can call the setTags method with an NSArray of NSString.

Tags are expected to contains only alphabetical characters and numbers. The method returns NO and an error if the passed NSArray is incorrect.

##### Clean Badge and notification methods
You have three clean methods available:
* - (void) cleanNotifications;
* - (void) cleanNotificationsAndBadge;
* - (void) cleanBadge;
When the badge are cleaned, the value is also reset to 0 on the Boxcar Push Service as well.

##### unregister
In case you want to completely and permanently stop using the push on that device, you can call the unregister method:
	[[Boxcar sharedInstance] unregisterDevice];

Note: This is not to use to temporarily disable push. Device unregistration destroy all reference to the device on Boxcar Push Service.

## Advanced topics

### InApp Push Notification
Boxcar Push Service implements a way to receive realtime notification from the server while the application is running or while it is still in the 10 minutes allowed for staying in background.

This allows to support a wider range of use case where Apple Push Notification only are not adequate.

For example, you can:
- Send much frequent notification through that mode (for realtime geolocation for example) while the application is running.
- You can send events to device that are triggered by server calculation, while the user is using the application (Sending badges for games for example).
- You can implement board games.
- And many more use cases …

Received events are simple NSString that can contains any type of JSON data structure.

#### BoxcarDelegate
To receive the events you need to implement BoxcarDelegate protocol with on method:
	- (void)didReceiveEvent:(NSString *)event;

Then, all you need is to call the two following method:
	[[Boxcar sharedInstance] setDelegate:self];
	[[Boxcar sharedInstance] connectToEventStreamWithId:[self makeUniqueString] error:nil];

The Id is any "alias", uniqueID, etc known by your server. If this is not an unguessable value, then you have to validate that value in some way in your mobile application, before passing it to the server.

You are done and you can start receiving inApp events send by the server, while the application is being using or running.

## Boxcar Push iOS Demo

You can learn how to integrate the Boxcar iOS SDK by studying the boxcar-ios-demo XCode project is an example on how to integrate with Boxcar Push Service. It put the step by step element into practice.

The XCode project for this demo application is provided with the SDK.








[^1]:	Sandbox is for "development" mode. You use it for applications uploaded to your device directly from XCode.

[^2]:	Device tokens are stored on Boxcar Push Service and are not expected to be used by developer to send push notifications throught our service.

[^3]:	If the alias you pass to Boxcar Push Service has not been validated by your app and cannot be trusted, consider the risk of hijack of notifications by someone using an illegitimate alias.

[1]:	mailto:support@boxcar.uservoice.com
[2]:	http://developer.apple.com/library/ios/%23documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/ProvisioningDevelopment/ProvisioningDevelopment.html

[image-1]:	push_console_project_list.png
