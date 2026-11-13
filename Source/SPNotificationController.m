//
//  SPNotificationController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Nov 28, 2008.
//  Copyright (c) 2008 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPNotificationController.h"
#import "SPDatabaseDocument.h"
#import "SPWindowController.h"
#import "SPAppController.h"

#include <mach/mach_time.h>

static SPNotificationController *sharedNotificationController = nil;

@class SPWindowController;

// Notification intermediary excision (SDS-10 10.6, second half):
// SPNotificationController keeps its posting signatures (internal
// call sites are unchanged in shape) but conforms to the native
// NSUserNotificationCenterDelegate in this extension only -- no
// third-party notification protocol, framework, or helper app remains.
@interface SPNotificationController () <NSUserNotificationCenterDelegate>
@end

@implementation SPNotificationController

/**
 * Returns the shared notification controller.
 */
+ (SPNotificationController *)sharedNotificationController
{
    @synchronized(self) {
        if (sharedNotificationController == nil) {
            sharedNotificationController = [[super allocWithZone:NULL] init];
        }
    }
    
    return sharedNotificationController;
}

+ (id)allocWithZone:(NSZone *)zone
{    
    @synchronized(self) {
		return [[self sharedNotificationController] retain]; 
    } 
	
	return nil;
}

- (id)init
{
    if ((self = [super init])) {
        // Register nothing with any intermediary: install this
        // controller as the NSUserNotificationCenter delegate so
        // banners present while the app is active and clicks are
        // delivered back to the posting bundle.
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
		
		timingNotificationName = nil;
		timingNotificationStart = 0;
		
		longRunningQueryNotificationTime = [[NSUserDefaults standardUserDefaults] floatForKey:SPLongRunningQueryNotificationTime];
    }
    
    return self;
}

#pragma mark -

/**
 * Posts a notification using the supplied details and default values.
 * Calls the notification after a tiny delay to allow isKeyWindow to have updated
 * after tasks.
 */
- (void)notifyWithTitle:(NSString *)title description:(NSString *)description document:(SPDatabaseDocument *)document notificationName:(NSString *)name
{
	// Ensure that the delayed notification call is made on the main thread
	if (![NSThread isMainThread]) {
		[[self onMainThread] notifyWithTitle:title description:description document:document notificationName:name];
		return;
	}

	NSMutableDictionary *notificationDictionary = [NSMutableDictionary dictionary];
	
	[notificationDictionary setObject:title forKey:@"title"];
	[notificationDictionary setObject:description forKey:@"description"];
	[notificationDictionary setObject:document forKey:@"document"];
	[notificationDictionary setObject:name forKey:@"name"];
	[notificationDictionary setObject:@{@"notificationDocumentHash" : @([document hash])} forKey:@"clickContext"];

	[self performSelector:@selector(notifyWithObject:) withObject:notificationDictionary afterDelay:0.1];
}

/**
 * Posts a notification, using a NSDictionary to contain all arguments.
 * Allows calling either with an NSThread or afterDelay as it only accepts a
 * single argument.
 */
- (void)notifyWithObject:(NSDictionary *)notificationDictionary
{
	[self notifyWithTitle:[notificationDictionary objectForKey:@"title"]
			  description:[notificationDictionary objectForKey:@"description"]
				 document:[notificationDictionary objectForKey:@"document"]
		 notificationName:[notificationDictionary objectForKey:@"name"]
				 iconData:nil
				 priority:0
				 isSticky:NO
			 clickContext:[notificationDictionary objectForKey:@"clickContext"]];
}

/**
 * Posts a notification using the supplied details and effectively ignoring the default values.
 */
- (void)notifyWithTitle:(NSString *)title description:(NSString *)description document:(SPDatabaseDocument *)document notificationName:(NSString *)name iconData:(NSData *)data priority:(NSInteger)priority isSticky:(BOOL)sticky clickContext:(id)clickContext
{
	BOOL postNotification = YES;

	// Don't post the notification if the notification document is frontmost
	// as that suggests the user is already viewing the notification result.
	if ([[document parentWindow] isKeyWindow] && 
		[[[document parentTabViewItem] tabView] selectedTabViewItem] == [document parentTabViewItem])
	{
		postNotification = NO;
	}

	// If a timing notification name exists, check to see if it matches the notification name;
	// if it does, and the time exceeds the threshold, display the notification even for
	// frontmost windows to provide feedback for long-running tasks.
	if (timingNotificationName && [timingNotificationName isEqualToString:name]) {
		if ([NSDate monotonicTimeInterval] > (longRunningQueryNotificationTime * 1000) + timingNotificationStart) {
			postNotification = YES;
		}
		
		SPClear(timingNotificationName);
	}

    // Post notification only if preference is set and visibility has been confirmed
	if (postNotification && [[NSUserDefaults standardUserDefaults] boolForKey:SPNotificationsEnabled]) {
		// Native posting (SDS-10 10.6): the notification is delivered
		// by this process, from the main bundle. Notification Center
		// attributes it to this bundle by construction; the title is
		// the ship name read from the main bundle's own Info.plist at
		// runtime, the notification type is carried as the subtitle,
		// and the supplied description is the body -- the same six
		// notification types the registration ticket used to declare
		// (Connected, Disconnected, Import Finished, Export Finished,
		// Syntax Copied, Query Finished), now with no intermediary.
		NSUserNotification *notification = [[NSUserNotification alloc] init];
		notification.title = [[self class] notificationApplicationName];
		notification.subtitle = title;
		notification.informativeText = description;
		if ([clickContext isKindOfClass:[NSDictionary class]]) {
			notification.userInfo = (NSDictionary *)clickContext;
		}
		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
		[notification release];
	}
}

// SDS-10 10.6 (notification identity): the banner title is read
// from the main bundle's own Info.plist at runtime (CFBundleName,
// then CFBundleDisplayName) -- never a hardcoded upstream name, and
// never a name asserted to a third-party intermediary: posting is
// native (above), so Notification Center attributes the
// notification to this bundle
// (com.detroitautomationacademy.sequelpro) by construction. The
// literal fallback covers only a bundle with no name keys at all.
+ (NSString *)notificationApplicationName
{
	NSString *name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	if (![name length]) {
		name = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	}
	if (![name length]) {
		name = @"Sequel Pro";
	}
	return name;
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
	return YES;
}

/**
 * React to a click on the notification (native center delegate;
 * the document hash travels in the notification's userInfo, the
 * same click context the old intermediary path carried).
 */
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
	NSDictionary *clickContext = [notification userInfo];
	[center removeDeliveredNotification:notification];
	if (clickContext && [clickContext objectForKey:@"notificationDocumentHash"]) {
		NSUInteger documentHash = [[clickContext objectForKey:@"notificationDocumentHash"] unsignedIntegerValue];

		// Loop through the windows, looking for the document
		for (NSWindow *eachWindow in [SPAppDelegate orderedDatabaseConnectionWindows])
		{
			for (SPDatabaseDocument *eachDocument in [[eachWindow windowController] documents])
			{
				if ([eachDocument hash] == documentHash) {
					[NSApp activateIgnoringOtherApps:YES];
					[eachDocument makeKeyDocument];
					return;
				}
			}
		}
	}
}

/**
 * Start the notification timer for a specific notification name.  Only one notification
 * timer can run at once, and tracks the time between this start and the notification
 * being posted; if the notification is posted after the header-defined boundary, the
 * notification will then be shown even if the app is frontmost.
 */
- (void)setVisibilityForNotificationName:(NSString *)name
{
	if (timingNotificationName) {
		SPClear(timingNotificationName);
	}
	
	timingNotificationName = [[NSString alloc] initWithString:name];
	timingNotificationStart = [NSDate monotonicTimeInterval];
}

@end
