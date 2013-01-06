//  DTAppController.m
//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DTAppController.h"

#import "DSAppleScriptUtilities.h"
#import "DTPrefsRegController.h"
#import "DTPrefsWindowController.h"
#import "DTTermWindowController.h"
#import "Finder.h"
#import "GrowlApplicationBridge.h"
//#import "Licensing.h"
#import "PathFinder.h"
#import "RTFWindowController.h"

#import "DSLicenseFileFinder.h"

NSString* DTResultsToKeepKey = @"DTResultsToKeep";
NSString* DTHotkeyAlsoDeactivatesKey = @"DTHotkeyAlsoDeactivates";
NSString* DTShowDockIconKey = @"DTShowDockIcon";
NSString* DTTextColorKey = @"DTTextColor";
NSString* DTFontNameKey = @"DTFontName";
NSString* DTFontSizeKey = @"DTFontSize";
NSString* DTDisableAntialiasingKey = @"DTDisableAntialiasing";

OSStatus DTHotKeyHandler(EventHandlerCallRef nextHandler,EventRef theEvent,
						 void *userData) {
	[[NSApp delegate] hotkeyPressed];
	return noErr;
}


@implementation DTAppController

#ifndef MAC_APP_STORE
@synthesize sparkleUpdater;
#endif

@synthesize numCommandsExecuted, termWindowController;

- (void)applicationWillFinishLaunching:(NSNotification*)ntf {
	// Ignore SIGPIPE
	signal(SIGPIPE, SIG_IGN);
	
	// Set some environment variables for our child processes
	setenv("TERM_PROGRAM", "DTerm", 1);
	setenv("TERM_PROGRAM_VERSION", [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] cStringUsingEncoding:NSASCIIStringEncoding], 1);
	
	NSDictionary* defaultsDict = [NSDictionary dictionaryWithObjectsAndKeys:
								  @"5", DTResultsToKeepKey,
								  [NSNumber numberWithBool:NO], DTHotkeyAlsoDeactivatesKey,
								  [NSNumber numberWithBool:YES], DTShowDockIconKey,
								  [NSKeyedArchiver archivedDataWithRootObject:[[NSColor whiteColor] colorWithAlphaComponent:0.9]], DTTextColorKey,
								  @"Monaco", DTFontNameKey,
								  [NSNumber numberWithFloat:10.0], DTFontSizeKey,
								  [NSNumber numberWithBool:NO], DTDisableAntialiasingKey,
								  nil];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
	
	[self loadStats];
	
	// Register for URL handling
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
													   andSelector:@selector(getURL:withReplyEvent:)
													 forEventClass:kInternetEventClass
														andEventID:kAEGetURL];
	
	if([[NSUserDefaults standardUserDefaults] boolForKey:DTShowDockIconKey]) {
		ProcessSerialNumber psn = { 0, kCurrentProcess };
		OSStatus err = TransformProcessType(&psn, kProcessTransformToForegroundApplication);
		if(err != noErr)
			NSLog(@"Error making DTerm non-LSUIElement: %d", err);
		else {
			NSDictionary* appleScriptError = nil;
			
			// TransformProcessType doesn't show the menubar, and the usual things don't work
			// See <https://decimus.fogbugz.com/default.asp?10520> for the cocoa-dev email that this is based on
			NSString* frontmostApp = [DSAppleScriptUtilities stringFromAppleScript:@"tell application \"System Events\" to name of first process whose frontmost is true"
																			 error:&appleScriptError];
			if(frontmostApp)
				[[NSWorkspace sharedWorkspace] launchApplication:frontmostApp];
			else
				NSLog(@"Couldn't get frontmost app from System Events: %@", appleScriptError);
			
			if(![DSAppleScriptUtilities bringApplicationToFront:@"DTerm" error:&appleScriptError])
				NSLog(@"Error bringing DTerm back to the front: %@", appleScriptError);
		}
	}
}

- (void)applicationDidFinishLaunching:(NSNotification*)ntf {
	if(!AXAPIEnabled() && !AXIsProcessTrusted()) {
		[self.prefsWindowController showAccessibility:self];
	}
//	else if(!IS_REGISTERED) {
//		[self.prefsWindowController showRegistration:self];
//	}
	
	// Workaround for Growl bug in Growl 1.1
	[GrowlApplicationBridge setGrowlDelegate:@""];
	
//	if(!IS_REGISTERED) {
//		[[NSGarbageCollector defaultCollector] disableCollectorForPointer:[[DSLicenseFileFinder alloc] initWithUTI:@"net.decimus.dterm.license"
//																										  delegate:self]];
//	}
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	if(!flag) {
		[self performSelector:@selector(showPrefs:)
				   withObject:nil
				   afterDelay:0.0];
	}
	
	return YES;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
	if(![[NSFileManager defaultManager] fileExistsAtPath:filename])
		return NO;
	
	NSURL* fileURL = [NSURL fileURLWithPath:filename];
	
	FSRef fsRef;
	if(!CFURLGetFSRef((CFURLRef)fileURL, &fsRef))
		return NO;
	
	CFTypeRef outValue;
	OSStatus err = LSCopyItemAttribute(&fsRef, kLSRolesAll, kLSItemContentType, &outValue);
	if(outValue)
		CFMakeCollectable(outValue);
	if(noErr != err)
		return NO;
	
	if(kCFCompareEqualTo != CFStringCompare(outValue, CFSTR("net.decimus.dterm.license"), kCFCompareCaseInsensitive))
		return NO;
	
//	if(!IS_REGISTERED)
//		[self.prefsWindowController.regPrefsViewController acceptLicenseURL:fileURL];
//	[self.prefsWindowController showRegistration:self];
	return YES;
}

- (void)awakeFromNib {
	termWindowController = [[DTTermWindowController alloc] init];
	
	// Install event handler for hotkey events
	EventTypeSpec theTypeSpec[] =
	{
		{ kEventClassKeyboard, kEventHotKeyPressed },
		//{ kEventClassKeyboard, kEventHotKeyReleased }
	};
	InstallApplicationEventHandler(&DTHotKeyHandler, 1, theTypeSpec, NULL, NULL);

	[self loadHotKeyFromUserDefaults];
}

- (DTPrefsWindowController*) prefsWindowController {
	if(!prefsWindowController)
		prefsWindowController = [[DTPrefsWindowController alloc] init];
	return prefsWindowController;
}

- (KeyCombo)hotKey {
	return hotKey;
}

- (void)setHotKey:(KeyCombo)newHotKey {
	// Unregister old hotkey, if necessary
	if(hotKeyRef) {
		UnregisterEventHotKey(hotKeyRef);
		hotKeyRef = NULL;
	}
	
	// Save hotkey for the future
	hotKey = newHotKey;
	[self saveHotKeyToUserDefaults];
	
	// Register new hotkey, if we have one
	if((hotKey.code != -1) && (hotKey.flags != 0)) {
		EventHotKeyID hotKeyID = { 'htk1', 1 };
		RegisterEventHotKey(hotKey.code, 
							SRCocoaToCarbonFlags(hotKey.flags),
							hotKeyID,
							GetApplicationEventTarget(), 
							0, 
							&hotKeyRef);
	}
}

- (void)saveHotKeyToUserDefaults {
	KeyCombo myHotKey = [self hotKey];
	
	NSDictionary* hotKeyDict = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithUnsignedInt:myHotKey.flags], @"flags",
								[NSNumber numberWithShort:myHotKey.code], @"code",
								nil];
	[[NSUserDefaults standardUserDefaults] setObject:hotKeyDict forKey:@"DTHotKey"];
}

- (void)loadHotKeyFromUserDefaults {
	KeyCombo myHotKey = { NSCommandKeyMask | NSShiftKeyMask, 36 /* return */ };
	
	NSDictionary* hotKeyDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"DTHotKey"];
	NSNumber* newFlags = [hotKeyDict objectForKey:@"flags"];
	NSNumber* newCode = [hotKeyDict objectForKey:@"code"];
	if(newFlags)
		myHotKey.flags = [newFlags unsignedIntValue];
	if(newCode)
		myHotKey.code = [newCode shortValue];
	
	[self setHotKey:myHotKey];
}

- (IBAction)showPrefs:(id)sender {
	[self.prefsWindowController showPrefs:sender];
}

- (NSRect)windowFrameOfAXWindow:(CFTypeRef)axWindow {
	AXError axErr = kAXErrorSuccess;
	
	// Get AXPosition of the main window
	CFTypeRef axPosition = NULL;
	axErr = AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute, &axPosition);
	NSMakeCollectable(axPosition);
	if((axErr != kAXErrorSuccess) || !axPosition) {
		NSLog(@"Couldn't get AXPosition: %d", axErr);
		return NSZeroRect;
	}
	
	// Convert to CGPoint
	CGPoint realAXPosition;
	if(!AXValueGetValue(axPosition, kAXValueCGPointType, &realAXPosition)) {
		NSLog(@"Couldn't extract CGPoint from AXPosition");
		return NSZeroRect;
	}
	
	// Get AXSize
	CFTypeRef axSize = NULL;
	axErr = AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute, &axSize);
	NSMakeCollectable(axSize);
	if((axErr != kAXErrorSuccess) || !axSize) {
		NSLog(@"Couldn't get AXSize: %d", axErr);
		return NSZeroRect;
	}
	
	// Convert to CGSize
	CGSize realAXSize;
	if(!AXValueGetValue(axSize, kAXValueCGSizeType, &realAXSize)) {
		NSLog(@"Couldn't extract CGSize from AXSize");
		return NSZeroRect;
	}
	
	NSRect windowBounds;
	windowBounds.origin.x = realAXPosition.x;
	windowBounds.origin.y = realAXPosition.y + 20.0;
	windowBounds.size.width = realAXSize.width;
	windowBounds.size.height = realAXSize.height - 20.0;
	return windowBounds;
}

- (NSString*)fileAXURLStringOfAXUIElement:(AXUIElementRef)uiElement {
	CFTypeRef axURL = NULL;
	
	AXError axErr = AXUIElementCopyAttributeValue(uiElement, kAXURLAttribute, &axURL);
	NSMakeCollectable(axURL);
	if((axErr != kAXErrorSuccess) || !axURL)
		return nil;
	
	// OK, we have some kind of AXURL attribute, but that could either be a string or a URL
	
	if(CFGetTypeID(axURL) == CFStringGetTypeID()) {
		if([(NSString*)axURL hasPrefix:@"file:///"])
			return (NSString*)axURL;
		else
			return nil;
	}
	
	if(CFGetTypeID(axURL) == CFURLGetTypeID()) {
		if([(NSURL*)axURL isFileURL])
			return [(NSURL*)axURL absoluteString];
		else
			return nil;
	}
	
	// Unknown type...
	return nil;
}

- (BOOL)findWindowURL:(NSURL**)windowURL selectionURLs:(NSArray**)selectionURLStrings windowFrame:(NSRect*)windowFrame ofAXApplication:(CFTypeRef)focusedApplication {
	AXError axErr = kAXErrorSuccess;
	
	if(windowURL)
		*windowURL = nil;
	if(selectionURLStrings)
		*selectionURLStrings = nil;
	if(windowFrame)
		*windowFrame = NSZeroRect;
	
	// Mechanism 1: Find front window AXDocument (a CFURL), and use that window
	
	// Follow to main window
	CFTypeRef mainWindow = NULL;
	axErr = AXUIElementCopyAttributeValue(focusedApplication, kAXMainWindowAttribute, &mainWindow);
	NSMakeCollectable(mainWindow);
	if((axErr != kAXErrorSuccess) || !mainWindow) {
#ifdef DEVBUILD
		NSLog(@"Couldn't get main window: %d", axErr);
#endif
		goto failedAXDocument;
	}
	
	// Get the window's AXDocument URL string
	CFTypeRef axDocumentURLString = NULL;
	axErr = AXUIElementCopyAttributeValue(mainWindow, kAXDocumentAttribute, &axDocumentURLString);
	NSMakeCollectable(axDocumentURLString);
	if((axErr != kAXErrorSuccess) || !axDocumentURLString) {
#ifdef DEVBUILD
		NSLog(@"Couldn't get AXDocument: %d", axErr);
#endif
		goto failedAXDocument;
	}
	
	// OK, we're a go with this method!
	if(windowURL)
		*windowURL = [NSURL URLWithString:(NSString*)axDocumentURLString];
	if(selectionURLStrings)
		*selectionURLStrings = [NSArray arrayWithObject:(NSString*)axDocumentURLString];
	if(windowFrame)
		*windowFrame = [self windowFrameOfAXWindow:mainWindow];
	return YES;
	
	
failedAXDocument:	;
	
	// Mechanism 2: Find focused UI element and try to find a selection from it.
	
	// Find focused UI element
	CFTypeRef focusedUIElement = NULL;
	axErr = AXUIElementCopyAttributeValue(focusedApplication, kAXFocusedUIElementAttribute, &focusedUIElement);
	NSMakeCollectable(focusedUIElement);
	if((axErr != kAXErrorSuccess) || !focusedUIElement) {
#ifdef DEVBUILD
		NSLog(@"Couldn't get AXFocusedUIElement");
#endif
		goto failedAXFocusedUIElement;
	}
	
	// Does the focused UI element have any selected children or selected rows? Great for file views.
	CFTypeRef focusedSelectedChildren = NULL;
	axErr = AXUIElementCopyAttributeValue(focusedUIElement, kAXSelectedChildrenAttribute, &focusedSelectedChildren);
	NSMakeCollectable(focusedSelectedChildren);
	if((axErr != kAXErrorSuccess) || !focusedSelectedChildren || !CFArrayGetCount(focusedSelectedChildren)) {
		axErr = AXUIElementCopyAttributeValue(focusedUIElement, kAXSelectedRowsAttribute, &focusedSelectedChildren);
		NSMakeCollectable(focusedSelectedChildren);
	}
	if((axErr == kAXErrorSuccess) && focusedSelectedChildren) {
		// If it *worked*, we see if we can extract URLs from these selected children
		NSMutableArray* tmpSelectionURLs = [NSMutableArray arrayWithCapacity:CFArrayGetCount(focusedSelectedChildren)];
		for(NSUInteger i=0; i<CFArrayGetCount(focusedSelectedChildren); i++) {
			CFTypeRef selectedChild = CFArrayGetValueAtIndex(focusedSelectedChildren, i);
			NSString* selectedChildURLString = [self fileAXURLStringOfAXUIElement:selectedChild];
			if(selectedChildURLString)
				[tmpSelectionURLs addObject:selectedChildURLString];
		}
		
		// If we have selection URLs now, grab the window the focused UI element belongs to
		if([tmpSelectionURLs count]) {
			CFTypeRef focusWindow = NULL;
			axErr = AXUIElementCopyAttributeValue(focusedUIElement, kAXWindowAttribute, &focusWindow);
			NSMakeCollectable(focusWindow);
			if((axErr == kAXErrorSuccess) && focusWindow) {
				// We're good with this! Return the values.
				if(selectionURLStrings)
					*selectionURLStrings = tmpSelectionURLs;
				if(windowFrame)
					*windowFrame = [self windowFrameOfAXWindow:focusWindow];
				return YES;
			}
		}
	}
	
	// Does the focused UI element have an AXURL of its own?
	NSString* focusedUIElementURLString = [self fileAXURLStringOfAXUIElement:focusedUIElement];
	if(focusedUIElementURLString) {
		CFTypeRef focusWindow = NULL;
		axErr = AXUIElementCopyAttributeValue(focusedUIElement, kAXWindowAttribute, &focusWindow);
		NSMakeCollectable(focusWindow);
		if((axErr == kAXErrorSuccess) && focusWindow) {
			// We're good with this! Return the values.
			if(selectionURLStrings)
				*selectionURLStrings = [NSArray arrayWithObject:focusedUIElementURLString];
			if(windowFrame)
				*windowFrame = [self windowFrameOfAXWindow:focusWindow];
			return YES;
		}
	}
	
	
failedAXFocusedUIElement:
	return NO;
}

- (void)hotkeyPressed {
//	NSLog(@"HotKey pressed");
//	NSLog(@"AXAPIEnabled %d, AXIsProcessTrusted %d", AXAPIEnabled(), AXIsProcessTrusted());
	
	// See if it's already visible
	if([[termWindowController window] isVisible]) {
		// Yep, it's visible...does the user want us to deactivate?
		if([[NSUserDefaults standardUserDefaults] boolForKey:DTHotkeyAlsoDeactivatesKey])
			[termWindowController deactivate];
		
		return;
	}
	
	NSString* workingDirectory = nil;
	NSURL* frontWindowURL = nil;
	NSArray* selectionURLStrings = nil;
	NSRect frontWindowBounds = NSZeroRect;
	
	NSString* frontmostAppBundleID = [[[NSWorkspace sharedWorkspace] activeApplication] objectForKey:@"NSApplicationBundleIdentifier"];
	
	// If the Finder is frontmost, talk to it using ScriptingBridge
	if([frontmostAppBundleID isEqualToString:@"com.apple.finder"]) {
		FinderApplication* finder = [SBApplication applicationWithBundleIdentifier:@"com.apple.finder"];
		
		// Selection URLs
		@try {
//			NSLog(@"selection: %@, insertionLocation: %@",
//				  [[finder.selection get] valueForKey:@"URL"],
//				  [[finder.insertionLocation get] valueForKey:@"URL"]);
			
			NSArray* selection = [finder.selection get];
			if(![selection count]) {
				SBObject* insertionLocation = [finder.insertionLocation get];
				if(!insertionLocation)
					return;
				
				selection = [NSArray arrayWithObject:insertionLocation];
			}
			
			// Get the URLs of the selection
			selectionURLStrings = [selection valueForKey:@"URL"];
			
			// If any of it ended up as NSNull, dump the whole thing
			if([selectionURLStrings containsObject:[NSNull null]]) {
				selection = nil;
				selectionURLStrings = nil;
			}
		}
		@catch (NSException* e) {
			// *shrug*...guess we can't get a selection
		}
		
		
		// If insertion location is desktop, use the desktop as the WD
		@try {
			NSString* insertionLocationURL = [[finder.insertionLocation get] valueForKey:@"URL"];
			if(insertionLocationURL) {
				NSString* path = [[NSURL URLWithString:insertionLocationURL] path];
				if([[path lastPathComponent] isEqualToString:@"Desktop"])
					workingDirectory = path;
			}
		}
		@catch (NSException* e) {
			// *shrug*...guess we can't get insertion location
		}
		
		// If it wasn't the desktop, grab it from the frontmost window
		if(!workingDirectory) {
			@try {
				FinderFinderWindow* frontWindow = [[finder FinderWindows] objectAtIndex:0];
				if([frontWindow exists]) {
					
					
					NSString* urlString = [[frontWindow.target get] valueForKey:@"URL"];
					if(urlString) {
						NSURL* url = [NSURL URLWithString:urlString];
						if(url && [url isFileURL]) {
							frontWindowBounds = frontWindow.bounds;
							workingDirectory = [url path];
						}
					}
				}
			}
			@catch (NSException* e) {
				// Fall through to the default attempts to set WD from selection
			}
		}
	}
	
	// Also use ScriptingBridge special case for Path Finder
	else if([frontmostAppBundleID isEqualToString:@"com.cocoatech.PathFinder"]) {
		PathFinderApplication* pf = [SBApplication applicationWithBundleIdentifier:@"com.cocoatech.PathFinder"];
		
		// Selection URLs
		@try {
			NSArray* selection = pf.selection;
			if([selection count]) {
				selectionURLStrings = [selection valueForKey:@"URL"];
			}
		}
		@catch (NSException* e) {
			// *shrug*...guess we can't get a selection
		}
		
		@try {
			SBElementArray* finderWindows = [pf finderWindows];
			if([finderWindows count]) {
				PathFinderFinderWindow* frontWindow = [finderWindows objectAtIndex:0];
				// [frontWindow exists] returns false here (???), but it works anyway
				frontWindowBounds = frontWindow.bounds;
				frontWindowBounds.origin.y += 20.0;
				
				NSString* urlString = [[frontWindow.target get] valueForKey:@"URL"];
				NSURL* url = [NSURL URLWithString:urlString];
				if(url && [url isFileURL])
					workingDirectory = [url path];
			}
		}
		@catch (NSException* e) {
			// Fall through to the default attempts to set WD from selection
		}
		
	}

	// Otherwise, try to talk to the frontmost app with the Accessibility APIs
	else if(AXAPIEnabled() || AXIsProcessTrusted()) {
		// Use Accessibility API
		AXError axErr = kAXErrorSuccess;
		
		// Grab system-wide UI Element
		AXUIElementRef systemElement = AXUIElementCreateSystemWide();
		if(!systemElement) {
			NSLog(@"Couldn't get systemElement");
			goto done;
		}
		CFMakeCollectable(systemElement);
		
		// Follow to focused application
		CFTypeRef focusedApplication = NULL;
		axErr = AXUIElementCopyAttributeValue(systemElement, 
											  kAXFocusedApplicationAttribute,
											  &focusedApplication);
		if((axErr != kAXErrorSuccess) || !focusedApplication) {
			NSLog(@"Couldn't get focused application: %d", axErr);
			goto done;
		}
		CFMakeCollectable(focusedApplication);
		
		[self findWindowURL:&frontWindowURL selectionURLs:&selectionURLStrings windowFrame:&frontWindowBounds ofAXApplication:focusedApplication];
	}
	
	// Numbers returned by AS are funky; adjust to NSWindow coordinates
	if(!NSEqualRects(frontWindowBounds, NSZeroRect)) {
		CGFloat screenHeight = [[[NSScreen screens] objectAtIndex:0] frame].size.height;
		frontWindowBounds.origin.y = screenHeight - frontWindowBounds.origin.y - frontWindowBounds.size.height;	
	}
	
//	NSLog(@"Front window URL: %@", frontWindowURL);
//	NSLog(@"Selection URLs: %@", selectionURLs);
//	NSLog(@"Front window bounds: %@", NSStringFromRect(frontWindowBounds));
	
done:
	// If there's no explicit WD, but we have a front window URL, try to deduce a working directory from that
	if(!workingDirectory && [frontWindowURL isFileURL]) {
		LSItemInfoRecord outItemInfo;
		if((noErr == LSCopyItemInfoForURL((CFURLRef)frontWindowURL, kLSRequestAllFlags, &outItemInfo)) &&
		   ((outItemInfo.flags & kLSItemInfoIsPackage) || !(outItemInfo.flags & kLSItemInfoIsContainer))) {
			// It's a package or not a container (i.e. a file); use its parent as the WD
			workingDirectory = [[frontWindowURL path] stringByDeletingLastPathComponent];
		} else {
			// It's not a package; use it directly as the WD
			workingDirectory = [frontWindowURL path];
		}
	}
	
	// If there's no explicit WD but we have a selection, try to deduce a working directory from that
	if(!workingDirectory && [selectionURLStrings count]) {
		NSURL* url = [NSURL URLWithString:[selectionURLStrings objectAtIndex:0]];
		NSString* path = [url path];
		workingDirectory = [path stringByDeletingLastPathComponent];
	}
	
	// default to the home directory if we *still* don't have an explicit WD
	if(!workingDirectory)
		workingDirectory = NSHomeDirectory();
	
	[termWindowController activateWithWorkingDirectory:workingDirectory
											 selection:selectionURLStrings
										   windowFrame:frontWindowBounds];
	
}

#pragma mark URL actions

- (void)getURL:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	NSString* urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	NSURL* url = [NSURL URLWithString:urlString];
	
	if(![[url scheme] isEqualToString:@"dterm"])
		return;
	
	NSString* service = [url host];
	
	// Preferences
	if([service isEqualToString:@"prefs"]) {
		NSString* prefsName = [url path];
		if([prefsName isEqualToString:@"/general"])
			[self.prefsWindowController showGeneral:self];
		else if([prefsName isEqualToString:@"/accessibility"])
			[self.prefsWindowController showAccessibility:self];
#ifndef MAC_APP_STORE
		else if([prefsName isEqualToString:@"/updates"])
			[self.prefsWindowController showUpdates:self];
#endif
//		else if([prefsName isEqualToString:@"/licensing"])
//			[self.prefsWindowController showRegistration:self];
	}
}

#pragma mark menu actions

- (IBAction)showAcknowledgments:(id)sender {
	if(!acknowledgmentsWindowController) {
		acknowledgmentsWindowController = [[RTFWindowController alloc] initWithRTFFile:[[NSBundle mainBundle] pathForResource:@"Acknowledgments" ofType:@"rtf"]];
	}
	
	[acknowledgmentsWindowController showWindow:sender];
}

- (IBAction)showLicense:(id)sender {
	if(!licenseWindowController) {
		licenseWindowController = [[RTFWindowController alloc] initWithRTFFile:[[NSBundle mainBundle] pathForResource:@"License" ofType:@"rtf"]];
	}
	
	[licenseWindowController showWindow:sender];
}

#pragma mark stats tracking

#include <sys/xattr.h>

static NSString* DTNumCommandsRunKey = @"DTNumCommandsRun";
static const char* DTNumCommandsRunXattrName = "net.decimus.dterm.commands";
#define MAXATTRSIZE 64

- (void)loadStats {
	NSInteger tmp;
	
	// Check NSUserDefaults first
	tmp = [[NSUserDefaults standardUserDefaults] integerForKey:DTNumCommandsRunKey];
	if(tmp > numCommandsExecuted)
		numCommandsExecuted = tmp;
	
	// Also check xattrs on user preferences folder
	FSRef fsRef;
	OSErr err = FSFindFolder(kUserDomain, kPreferencesFolderType, kDontCreateFolder, &fsRef);
	if(noErr != err)
		return;
	char path[PATH_MAX];
	err = FSRefMakePath(&fsRef, (UInt8*)path, PATH_MAX);
	if(noErr != err)
		return;
	
	UInt8 attr[MAXATTRSIZE];
	ssize_t attrSize;
	attrSize = getxattr(path, DTNumCommandsRunXattrName, attr, MAXATTRSIZE, 0, 0);
	if(attrSize > 0) {
		tmp = [[[NSString alloc] initWithBytes:attr length:attrSize encoding:NSUTF8StringEncoding] integerValue];
		if(tmp > numCommandsExecuted)
			numCommandsExecuted = tmp;
	}
}

- (void)saveStats {
	// Save to NSUserDefaults
	[[NSUserDefaults standardUserDefaults] setInteger:numCommandsExecuted forKey:DTNumCommandsRunKey];
	
	// Save to xattrs on user preferences folder
	FSRef fsRef;
	OSErr err = FSFindFolder(kUserDomain, kPreferencesFolderType, kCreateFolder, &fsRef);
	if(noErr != err)
		return;
	char path[PATH_MAX];
	err = FSRefMakePath(&fsRef, (UInt8*)path, PATH_MAX);
	if(noErr != err)
		return;
	
	const char* commandsAttr = [[[NSNumber numberWithUnsignedInteger:numCommandsExecuted] stringValue] cStringUsingEncoding:NSUTF8StringEncoding];
	setxattr(path, DTNumCommandsRunXattrName, commandsAttr, strlen(commandsAttr), 0, 0);
}

#pragma mark font panel support

- (void)changeFont:(id)sender{
	/*
	 This is the message the font panel sends when a new font is selected
	 */
	
	// Get selected font
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	NSFont *selectedFont = [fontManager selectedFont];
	if(!selectedFont) {
		selectedFont = [NSFont systemFontOfSize:[NSFont systemFontSize]];
	}
	NSFont *panelFont = [fontManager convertFont:selectedFont];
	
	// Get and store details of selected font
	// Note: use fontName, not displayName.  The font name identifies the font to
	// the system, we use a value transformer to show the user the display name
	NSNumber *fontSize = [NSNumber numberWithFloat:[panelFont pointSize]];	
	
	id currentPrefsValues =
	[[NSUserDefaultsController sharedUserDefaultsController] values];
	[currentPrefsValues setValue:[panelFont fontName] forKey:DTFontNameKey];
	[currentPrefsValues setValue:fontSize forKey:DTFontSizeKey];
}

//#pragma mark licensing support
//
//- (void)licenseFileFinder:(DSLicenseFileFinder*)lff foundLicense:(NSString*)path {
//	//NSLog(@"notified of license file: %@", path);
//	
//	if(IS_REGISTERED) {
//		[lff stopQuery];
//		[[NSGarbageCollector defaultCollector] enableCollectorForPointer:lff];
//		return;
//	} else if(AskUserIfTheyWantToInstallLicenseFile(path)) {
//		[self.prefsWindowController.regPrefsViewController acceptLicenseURL:[NSURL fileURLWithPath:path]];
//	}
//}
//
//- (BOOL)installLicenseFromData:(NSData*)licData {
//	[self.prefsWindowController.regPrefsViewController willChangeValueForKey:@"isRegistered"];
//	[[NSUserDefaults standardUserDefaults] setObject:licData forKey:DTLicenseDataKey];
//	[self.prefsWindowController.regPrefsViewController didChangeValueForKey:@"isRegistered"];
//	
//	return IS_REGISTERED;
//}
//
//- (NSString*)storeProductID {
//	return @"6";
//}

@end
