//  DTPrefsWindowController.m
//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DTPrefsWindowController.h"

#import "DTAppController.h"
#import "DTPrefsAXController.h"
#import "FontNameToDisplayNameTransformer.h"
#import "Sparkle.h"
#import "SRRecorderControl.h"

#ifdef MAC_APP_STORE
#define PREFERENCES_NIB_NAME @"PreferencesMAS"
#else
#define PREFERENCES_NIB_NAME @"Preferences"
#endif

@implementation DTPrefsWindowController

//@synthesize regPrefsViewController;
@synthesize axPrefsController;

+ (void)initialize {
	// Create and register font name value transformer
	NSValueTransformer *transformer = [[FontNameToDisplayNameTransformer alloc] init];
	[NSValueTransformer setValueTransformer:transformer forName:@"FontNameToDisplayNameTransformer"];
}

- (id)init {
	if((self = [super initWithWindowNibName:PREFERENCES_NIB_NAME])) {
		[self setShouldCascadeWindows:NO];
		
		[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
	}
	
	return self;
}

// Don't allow closing if we can't commit editing
- (BOOL)windowShouldClose:(id)window {
	return [[self window] makeFirstResponder:nil];
}

- (void)windowDidLoad {
	[shortcutRecorder setAllowsKeyOnly:NO escapeKeysRecord:NO];
	[shortcutRecorder setKeyCombo:[[NSApp delegate] hotKey]];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
	[axPrefsController recheckGeneralAXAccess];
}

- (IBAction)showPrefs:(id)sender {
	if(![[self window] isVisible])
		[self showGeneral:sender];
	else {
		[[self window] center];
		[[self window] makeKeyAndOrderFront:sender];
	}
}

- (BOOL)shortcutRecorder:(SRRecorderControl *)aRecorder
			   isKeyCode:(NSInteger)keyCode
		   andFlagsTaken:(NSUInteger)flags
				  reason:(NSString **)aReason {
	return NO;
}

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder
	   keyComboDidChange:(KeyCombo)newKeyCombo {
//	NSLog(@"New key combo: key code %d, flags %d", newKeyCombo.code, newKeyCombo.flags);
	[[NSApp delegate] setHotKey:newKeyCombo];
}

- (void)showView:(NSView*)prefsView {
	NSWindow* prefsWindow = [self window];
	
	//blank view to stop flicker
	NSView *tempView = [[NSView alloc] initWithFrame:[[prefsWindow contentView] frame]];
    [prefsWindow setContentView:tempView];
    
    //mojo to get the right frame for the new window.
    NSRect newFrame = [prefsWindow frame];
    newFrame.size.height = [prefsView frame].size.height + 
	([prefsWindow frame].size.height - [[prefsWindow contentView] frame].size.height);
    newFrame.size.width = [prefsView frame].size.width;
    newFrame.origin.y += ([[prefsWindow contentView] frame].size.height - [prefsView frame].size.height);
    
    //set the frame to newFrame and animate it. (change animate:YES to animate:NO if you don't want this)
//    [prefsWindow setShowsResizeIndicator:YES];
    [prefsWindow setFrame:newFrame display:YES animate:YES];
    //set the main content view to the new view
    [prefsWindow setContentView:prefsView];
	
	if (![prefsWindow isVisible]) {
		[[self window] center];
		[[self window] makeKeyAndOrderFront:self];
	}
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [toolbar valueForKeyPath:@"items.itemIdentifier"];
}

- (IBAction)showGeneral:(id)sender {
	// make sure we have a window
	[self window];
	
	// This method can be called programmatically, so make sure general toolbar icon is selected
	NSToolbar* toolbar = [[self window] toolbar];
	for(NSToolbarItem* item in [toolbar items]) {
		if([item tag] == 1 /* general tag */) {
			[toolbar setSelectedItemIdentifier:[item itemIdentifier]];
			break;
		}
	}
	
	[self showView:generalPrefsView];
}
- (IBAction)showAccessibility:(id)sender {
	// make sure we have a window
	[self window];
	
	// This method can be called programmatically, so make sure accessibility toolbar icon is selected
	NSToolbar* toolbar = [[self window] toolbar];
	for(NSToolbarItem* item in [toolbar items]) {
		if([item tag] == 2 /* accessibility tag */) {
			[toolbar setSelectedItemIdentifier:[item itemIdentifier]];
			break;
		}
	}
	
	[self showView:accessibilityPrefsView];
}
#ifndef MAC_APP_STORE
- (IBAction)showUpdates:(id)sender {
	// make sure we have a window
	[self window];
	
	// This method can be called programmatically, so make sure updates toolbar icon is selected
	NSToolbar* toolbar = [[self window] toolbar];
	for(NSToolbarItem* item in [toolbar items]) {
		if([item tag] == 3 /* updates tag */) {
			[toolbar setSelectedItemIdentifier:[item itemIdentifier]];
			break;
		}
	}
	
	[self showView:updatesPrefsView];
}
#endif


//- (IBAction)showRegistration:(id)sender {
//	// make sure we have a window
//	[self window];
//	
//	// This method can be called programmatically, so make sure licensing toolbar icon is selected
//	NSToolbar* toolbar = [[self window] toolbar];
//	for(NSToolbarItem* item in [toolbar items]) {
//		if([item tag] == 4 /* licensing tag */) {
//			[toolbar setSelectedItemIdentifier:[item itemIdentifier]];
//			break;
//		}
//	}
//	
//	[self showView:regPrefsView];
//}

#pragma mark font selection

- (IBAction)showFontPanel:(id)sender {
	// Get font name and size from user defaults
	NSDictionary *values = [[NSUserDefaultsController sharedUserDefaultsController] values];
	NSString *fontName = [values valueForKey:DTFontNameKey];
	CGFloat fontSize = [[values valueForKey:DTFontSizeKey] floatValue];
	
	// Create font from name and size; initialize font panel
    NSFont *font = [NSFont fontWithName:fontName size:fontSize];
	if(!font) {
		font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	}
	[[NSFontManager sharedFontManager] setSelectedFont:font 
											isMultiple:NO];
    [[NSFontManager sharedFontManager] orderFrontFontPanel:self];
	
	// Set window as firstResponder so we get changeFont: messages
    [[self window] makeFirstResponder:[self window]];
}

- (IBAction)resetColorAndFont:(id)sender {
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:DTFontNameKey];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:DTFontSizeKey];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:DTTextColorKey];
}

#pragma mark Updates support

#ifndef MAC_APP_STORE
- (IBAction)checkForUpdatesNow:(id)sender {
	[[[NSApp delegate] sparkleUpdater] checkForUpdates:sender];
}
#endif

@end
