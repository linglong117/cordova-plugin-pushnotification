//
//  AppDelegate+notification.m
//  pushtest
//
//  Created by Robert Easterday on 10/26/12.
//
//

#import "AppDelegate+notification.h"
#import "PushPlugin.h"
#import <objc/runtime.h>

#import "BPush.h"
#import "JSONKit.h"
#import "OpenUDID.h"

#define SUPPORT_IOS8 1


static char launchNotificationKey;

@implementation AppDelegate (notification)

//@dynamic appId, channelId, userId;

- (id) getCommandInstance:(NSString*)className
{
	return [self.viewController getCommandInstance:className];
}

// its dangerous to override a method from within a category.
// Instead we will use method swizzling. we set this up in the load call.
+ (void)load
{
    Method original, swizzled;
    
    
    original = class_getInstanceMethod(self, @selector(init));
    swizzled = class_getInstanceMethod(self, @selector(swizzled_init));
    method_exchangeImplementations(original, swizzled);
}

- (AppDelegate *)swizzled_init
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createNotificationChecker:)
               name:@"UIApplicationDidFinishLaunchingNotification" object:nil];
	
	// This actually calls the original init method over in AppDelegate. Equivilent to calling super
	// on an overrided method, this is not recursive, although it appears that way. neat huh?
	return [self swizzled_init];
}

// This code will be called immediately after application:didFinishLaunchingWithOptions:. We need
// to process notifications in cold-start situations
- (void)createNotificationChecker:(NSNotification *)notification
{
	if (notification)
	{
		NSDictionary *launchOptions = [notification userInfo];
		if (launchOptions)
			self.launchNotification = [launchOptions objectForKey: @"UIApplicationLaunchOptionsRemoteNotificationKey"];
        
//        PushPlugin *pushHandler = [self.viewController getCommandInstance:@"pushnotification"];
//        NSMutableDictionary* mutableUserInfo = [launchOptions mutableCopy];
//        [mutableUserInfo setValue:@"1" forKey:@"applicationLaunchNotification"];
//        [mutableUserInfo setValue:@"0" forKey:@"applicationStateActive"];
//        //[pushHandler.pendingNotifications addObject:mutableUserInfo];

        [BPush setupChannel:self.launchNotification];
        [BPush setDelegate:self];

        //[application setApplicationIconBadgeNumber:0];
        //NSLog(@"%f",[[[UIDevice currentDevice] systemVersion] floatValue]);
        
#if SUPPORT_IOS8
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            UIUserNotificationType myTypes = UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound;
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:myTypes categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        }else
#endif
        {
            UIRemoteNotificationType myTypes = UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound;
            [[UIApplication sharedApplication] registerForRemoteNotificationTypes:myTypes];
        }
	}
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {

    [BPush registerDeviceToken: deviceToken];
    
    //self.viewController.textView.text = [self.viewController.textView.text stringByAppendingFormat: @"Register device token: %@\n openudid: %@", deviceToken, [OpenUDID value]];
    NSLog(@"Register device token: %@\n openudid: %@", deviceToken, [OpenUDID value]);
    
    NSString* token = [[[[deviceToken description]
                         stringByReplacingOccurrencesOfString: @"<" withString: @""]
                        stringByReplacingOccurrencesOfString: @">" withString: @""]
                       stringByReplacingOccurrencesOfString: @" " withString: @""];
    
    
    
    [BPush bindChannel];
    NSLog(@"applicationWillEnterForeground appid : %@   userid: %@   channelid : %@ ",[BPush getAppId],[BPush getUserId],[BPush getChannelId]);
    
    PushPlugin *pushHandler = [self getCommandInstance:@"pushnotification"];
    
    NSMutableDictionary *resultInfo = [[NSMutableDictionary alloc] init];
    
    [resultInfo setValue:[BPush getUserId] forKey:@"user_id"];
    [resultInfo setValue:[BPush getAppId] forKey:@"app_id"];
    [resultInfo setValue:[BPush getChannelId] forKey:@"channel_id"];
    [resultInfo setObject:deviceToken forKey:@"deviceTokenData"];
    [resultInfo setObject:token forKey:@"deviceToken"];


    //NSError *error = nil;
//    NSMutableData *resultData = [[NSMutableData alloc] init];
//    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:resultData];
//    [archiver encodeObject:resultInfo forKey:@"IDTokenInfo"];
//    [archiver finishEncoding];
    
    [pushHandler didRegisterForRemoteNotificationsWithDeviceToken:resultInfo];
    
    // re-post ( broadcast )
    
    

    [[NSNotificationCenter defaultCenter] postNotificationName:CDVRemoteNotification object:token];

}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    PushPlugin *pushHandler = [self getCommandInstance:@"pushnotification"];
    [pushHandler didFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSLog(@"Receive Notify: %@", [userInfo JSONString]);
    NSString *alert = [[userInfo objectForKey:@"aps"] objectForKey:@"alert"];
    if (application.applicationState == UIApplicationStateActive) {
        // Nothing to do if applicationState is Inactive, the iOS already displayed an alert view.
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"易会通知"
                                                            message:[NSString stringWithFormat:@"易会通知信息:\n%@", alert]
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
    [application setApplicationIconBadgeNumber:0];
    
    [BPush handleNotification:userInfo];
    
    //self.viewController.textView.text = [self.viewController.textView.text stringByAppendingFormat:@"Receive notification:\n%@", [userInfo JSONString]];
    NSLog(@"Receive notification:\n%@", [userInfo JSONString]);
    
    // Get application state for iOS4.x+ devices, otherwise assume active
    UIApplicationState appState = UIApplicationStateActive;
    if ([application respondsToSelector:@selector(applicationState)]) {
        appState = application.applicationState;
    }
    
    if (appState == UIApplicationStateActive) {
        PushPlugin *pushHandler = [self getCommandInstance:@"pushnotification"];
        pushHandler.notificationMessage = userInfo;
        pushHandler.isInline = YES;
        [pushHandler notificationReceived];
    } else {
        //save it for later
        self.launchNotification = userInfo;
    }
}

//=======================================================
#if SUPPORT_IOS8
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
    //register to receive notifications
    [application registerForRemoteNotifications];
}
#endif


- (void) onMethod:(NSString*)method response:(NSDictionary*)data {
    NSLog(@"On method:%@", method);
    NSLog(@"data:%@", [data description]);
    NSDictionary* res = [[NSDictionary alloc] initWithDictionary:data];
    if ([BPushRequestMethod_Bind isEqualToString:method]) {
//        NSString *appid = [res valueForKey:BPushRequestAppIdKey];
//        NSString *userid = [res valueForKey:BPushRequestUserIdKey];
//        NSString *channelid = [res valueForKey:BPushRequestChannelIdKey];
        //NSString *requestid = [res valueForKey:BPushRequestRequestIdKey];
        int returnCode = [[res valueForKey:BPushRequestErrorCodeKey] intValue];
        
        if (returnCode == BPushErrorCode_Success) {
          
            // 在内存中备份，以便短时间内进入可以看到这些值，而不需要重新bind
//            self.appId = appid;
//            self.channelId = channelid;
//            self.userId = userid;
            
        }
    } else if ([BPushRequestMethod_Unbind isEqualToString:method]) {
        int returnCode = [[res valueForKey:BPushRequestErrorCodeKey] intValue];
        if (returnCode == BPushErrorCode_Success) {
            //            self.viewController.appidText.text = nil;
            //            self.viewController.useridText.text = nil;
            //            self.viewController.channelidText.text = nil;
        }
    }
    //self.viewController.textView.text = [[[NSString alloc] initWithFormat: @"%@ return: \n%@", method, [data description]] autorelease];
    NSLog(@"%@ return: \n%@", method, [data description]);
}


//- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
//    NSLog(@"Receive Notify: %@", [userInfo JSONString]);
//    NSString *alert = [[userInfo objectForKey:@"aps"] objectForKey:@"alert"];
//    if (application.applicationState == UIApplicationStateActive) {
//        // Nothing to do if applicationState is Inactive, the iOS already displayed an alert view.
//        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Did receive a Remote Notification"
//                                                            message:[NSString stringWithFormat:@"The application received this remote notification while it was running:\n%@", alert]
//                                                           delegate:self
//                                                  cancelButtonTitle:@"OK"
//                                                  otherButtonTitles:nil];
//        [alertView show];
//    }
//    [application setApplicationIconBadgeNumber:0];
//    
//    [BPush handleNotification:userInfo];
//    
//    //self.viewController.textView.text = [self.viewController.textView.text stringByAppendingFormat:@"Receive notification:\n%@", [userInfo JSONString]];
//    NSLog(@"Receive notification:\n%@", [userInfo JSONString]);
//}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    //    self.viewController.appidText.text = self.appId;
    //    self.viewController.useridText.text = self.userId;
    //    self.viewController.channelidText.text = self.channelId;
    //NSLog(@"applicationWillEnterForeground appid : %@   userid: %@   channelid : %@ ",self.appId,self.userId,self.channelId);
}

//- (void)applicationDidBecomeActive:(UIApplication *)application
//{
//    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
//    
//    //    self.viewController.appidText.text = [BPush getAppId];
//    //    self.viewController.useridText.text = [BPush getUserId];
//    //    self.viewController.channelidText.text = [BPush getChannelId];
//    
//    NSLog(@"applicationWillEnterForeground appid : %@   userid: %@   channelid : %@ ",[BPush getAppId],[BPush getUserId],[BPush getChannelId]);
//}

//========================================


// this happens while we are running ( in the background, or from within our own app )
// only valid if XAttender-Info.plist specifies a protocol to handle
- (BOOL)application:(UIApplication*)application openURL:(NSURL*)url sourceApplication:(NSString*)sourceApplication annotation:(id)annotation
{
    if (!url) {
        return NO;
    }
    
    // calls into javascript global function 'handleOpenURL'
    NSString* jsString = [NSString stringWithFormat:@"handleOpenURL(\"%@\");", url];
    [self.viewController.webView stringByEvaluatingJavaScriptFromString:jsString];
    
    // all plugins will get the notification, and their handlers will be called
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:CDVPluginHandleOpenURLNotification object:url]];
    
    return YES;
}

// repost all remote and local notification using the default NSNotificationCenter so multiple plugins may respond
- (void)            application:(UIApplication*)application
    didReceiveLocalNotification:(UILocalNotification*)notification
{
    // re-post ( broadcast )
    [[NSNotificationCenter defaultCenter] postNotificationName:CDVLocalNotification object:notification];
}

//- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
//{
//    // re-post ( broadcast )
//    NSString* token = [[[[deviceToken description]
//                         stringByReplacingOccurrencesOfString: @"<" withString: @""]
//                        stringByReplacingOccurrencesOfString: @">" withString: @""]
//                       stringByReplacingOccurrencesOfString: @" " withString: @""];
//
//    [[NSNotificationCenter defaultCenter] postNotificationName:CDVRemoteNotification object:token];
//}

//- (void)application:(UIApplication *)application
//    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
//{
//    // re-post ( broadcast )
//    [[NSNotificationCenter defaultCenter] postNotificationName:CDVRemoteNotificationError object:error];
//}

- (NSUInteger)application:(UIApplication*)application supportedInterfaceOrientationsForWindow:(UIWindow*)window
{
    // iPhone doesn't support upside down by default, while the iPad does.  Override to allow all orientations always, and let the root view controller decide what's allowed (the supported orientations mask gets intersected).
    NSUInteger supportedInterfaceOrientations = (1 << UIInterfaceOrientationPortrait) | (1 << UIInterfaceOrientationLandscapeLeft) | (1 << UIInterfaceOrientationLandscapeRight) | (1 << UIInterfaceOrientationPortraitUpsideDown);
    
    return supportedInterfaceOrientations;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication*)application
{
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    
    NSLog(@"active");
    
    NSLog(@"applicationWillEnterForeground appid : %@   userid: %@   channelid : %@ ",[BPush getAppId],[BPush getUserId],[BPush getChannelId]);
    
    //zero badge
    application.applicationIconBadgeNumber = 0;

    if (self.launchNotification) {
        PushPlugin *pushHandler = [self getCommandInstance:@"pushnotification"];
		
        pushHandler.notificationMessage = self.launchNotification;
        self.launchNotification = nil;
        [pushHandler performSelectorOnMainThread:@selector(notificationReceived) withObject:pushHandler waitUntilDone:NO];
    }
}

// The accessors use an Associative Reference since you can't define a iVar in a category
// http://developer.apple.com/library/ios/#documentation/cocoa/conceptual/objectivec/Chapters/ocAssociativeReferences.html
- (NSMutableArray *)launchNotification
{
   return objc_getAssociatedObject(self, &launchNotificationKey);
}

- (void)setLaunchNotification:(NSDictionary *)aDictionary
{
    objc_setAssociatedObject(self, &launchNotificationKey, aDictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

//- (void)setUserId:(NSString *)userId
//{
//    self.userId = userId;
//}
//
//- (void)setChannelId:(NSString *)channelId
//{
//    self.channelId = channelId;
//}
//
//- (void)setAppId:(NSString *)appId
//{
//    self.appId = appId;
//}


- (void)dealloc
{
    self.launchNotification	= nil; // clear the association and release the object
}




@end
