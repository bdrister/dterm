//
//  SUUpdater.h
//  Sparkle
//
//  Created by Andy Matuschak on 1/4/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//
// $Id: SUUpdater.h 27 2006-06-16 22:53:50Z atomicbird $
// $HeadURL: http://sparkleplus.googlecode.com/svn/tags/release-0.3/SUUpdater.h $

#import <Cocoa/Cocoa.h>

// Before you use Sparkle in your app, you must set SUFeedURL in Info.plist to the
// address of the appcast on your webserver. If you don't already have an 
// appcast, please see the Sparkle documentation to learn about how to set one up.

// .zip, .dmg, .tar, .tbz, .tgz archives are supported at this time.

// By default, Sparkle offers to show the user the release notes of the build they'll be
// getting, which it assumes are in the description (or body) field of the relevant RSS item.
// Set SUShowReleaseNotes to <false/> in Info.plist to hide the button.

@class SUAppcastItem, SUUpdateAlert, SUStatusController;
@interface SUUpdater : NSObject {
	SUAppcastItem *updateItem;
	
	SUStatusController *statusController;
	SUUpdateAlert *updateAlert;
	
	NSURLDownload *downloader;
	NSString *downloadPath;
			
	NSTimer *checkTimer;
	NSTimeInterval checkInterval;	
	
	BOOL verbose;
	BOOL updateInProgress;
	
	id delegate;
	
	IBOutlet NSWindow *profileMoreInfoWindow;
	IBOutlet NSView *profileMoreInfoView;
	IBOutlet NSButton *profileMoreInfoButton;
	IBOutlet NSTextField *checkForUpdatesText;
	BOOL moreInfoVisible;
}

// This IBAction is meant for a main menu item. Hook up any menu item to this action,
// and Sparkle will check for updates and report back its findings verbosely.
- (IBAction)checkForUpdates:sender;

// This method is similar to the above, but it's intended for updates initiated by
// the computer instead of by the user. It does not alert the user when he is up to date,
// and it remains silent about network errors in fetching the feed. This is what you
// want to call to update programmatically; only use checkForUpdates: with buttons and menu items.
- (void)checkForUpdatesInBackground;

// This method allows you to schedule a check to run every time interval. You can
// pass 0 to this method to cancel a previously scheduled timer. You probably don't want
// to call this directly: if you set a SUScheduledCheckInterval key in Info.plist or
// the user defaults, Sparkle will set this up for you automatically on startup. You might
// just want to call this every time the user changes the setting in the preferences.
- (void)scheduleCheckWithInterval:(NSTimeInterval)interval;

// Get information that will be included with update-check requests.  This method can be used
// whether or not profile information is enabled.  Use this method to show the user what kind
// of information will be included.  This method will invoke -updaterCustomizeProfileInfo: on
// the delegate, if it's implemented.
- (NSMutableArray *)systemProfileInformationArray;

- (IBAction)closeProfileInfoSheet:(id)sender;

@end
@interface NSObject (SUUpdaterDelegate)
// Specify whether the updater should include system-profile information with update checks.
- (BOOL)updaterShouldSendProfileInfo;
// This method gives the delegate the opportunity to customize the information that will
// be included with update checks.  Add or remove items from the dictionary as desired.
- (NSMutableArray *)updaterCustomizeProfileInfo:(NSMutableArray *)profileInfo;
@end