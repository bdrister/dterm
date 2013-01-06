//  DTPrefsWindowController.h
//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

//@class DTPrefsRegController;
@class DTPrefsAXController;
@class SRRecorderControl;

@interface DTPrefsWindowController : NSWindowController {
	IBOutlet SRRecorderControl* shortcutRecorder;
	
	IBOutlet NSView* generalPrefsView;
	IBOutlet NSView* accessibilityPrefsView;
#ifndef MAC_APP_STORE
	IBOutlet NSView* updatesPrefsView;
#endif
	IBOutlet NSView* regPrefsView;
	
//	IBOutlet DTPrefsRegController* regPrefsViewController;
	IBOutlet DTPrefsAXController* axPrefsController;
}

//@property DTPrefsRegController* regPrefsViewController;
@property DTPrefsAXController* axPrefsController;

- (IBAction)showPrefs:(id)sender;

- (IBAction)showGeneral:(id)sender;
- (IBAction)showAccessibility:(id)sender;
#ifndef MAC_APP_STORE
- (IBAction)showUpdates:(id)sender;
#endif
//- (IBAction)showRegistration:(id)sender;

- (IBAction)showFontPanel:(id)sender;
- (IBAction)resetColorAndFont:(id)sender;

#ifndef MAC_APP_STORE
- (IBAction)checkForUpdatesNow:(id)sender;
#endif

@end
