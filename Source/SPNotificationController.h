//
//  SPNotificationController.h
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
//
//  Notification intermediary excision (SDS-10 10.6.5; 2026-11-13):
//  this controller no longer imports or links any third-party
//  notification framework. The class keeps every posting signature
//  the call sites use; the implementation posts natively via
//  NSUserNotificationCenter from the main bundle.

#import "SPSingleton.h"

@class SPDatabaseDocument;

@interface SPNotificationController : SPSingleton
{
	NSString *timingNotificationName;
	
	double timingNotificationStart;
	
	CGFloat longRunningQueryNotificationTime;
}

// Singleton controller
+ (SPNotificationController *)sharedNotificationController;

// Post notification
- (void)notifyWithTitle:(NSString *)title 
			description:(NSString *)description
			   document:(SPDatabaseDocument *)document
	   notificationName:(NSString *)name;

- (void)notifyWithObject:(NSDictionary *)notificationDictionary;

- (void)notifyWithTitle:(NSString *)title 
			description:(NSString *)description 
			   document:(SPDatabaseDocument *)document
	   notificationName:(NSString *)name 
			   iconData:(NSData *)data 
			   priority:(NSInteger)priority 
			   isSticky:(BOOL)sticky 
		   clickContext:(id)clickContext;

// Timing functions
- (void)setVisibilityForNotificationName:(NSString *)name;

@end
