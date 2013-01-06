//  DTAppController.h
//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "SRCommon.h"

@class DTPrefsWindowController;
@class DTTermWindowController;
@class RTFWindowController;

#ifndef MAC_APP_STORE
@class SUUpdater;
#endif

extern NSString* DTResultsToKeepKey;
extern NSString* DTTextColorKey;
extern NSString* DTFontNameKey;
extern NSString* DTFontSizeKey;

@interface DTAppController : NSObject {
#ifndef MAC_APP_STORE
	IBOutlet SUUpdater* sparkleUpdater;
#endif
	DTPrefsWindowController* prefsWindowController;
	DTTermWindowController* termWindowController;
	
	RTFWindowController* acknowledgmentsWindowController;
	RTFWindowController* licenseWindowController;
	
	EventHotKeyRef hotKeyRef;
	KeyCombo hotKey;
	
	NSUInteger numCommandsExecuted;
}

#ifndef MAC_APP_STORE
@property (assign) SUUpdater* sparkleUpdater;
#endif
@property NSUInteger numCommandsExecuted;
@property (readonly) DTPrefsWindowController* prefsWindowController;
@property (readonly) DTTermWindowController* termWindowController;

- (IBAction)showPrefs:(id)sender;
- (IBAction)showAcknowledgments:(id)sender;
- (IBAction)showLicense:(id)sender;

- (KeyCombo)hotKey;
- (void)setHotKey:(KeyCombo)newHotKey;
- (void)hotkeyPressed;

- (void)saveHotKeyToUserDefaults;
- (void)loadHotKeyFromUserDefaults;

- (void)loadStats;
- (void)saveStats;

@end
