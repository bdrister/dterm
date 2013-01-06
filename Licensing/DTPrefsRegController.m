//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DTPrefsRegController.h"

#import "DSLicenseAutoDLWindowController.h"
#import "Licensing.h"

@interface DTPrefsRegController ()
- (void)acceptLicenseURL:(NSURL*)licenseURL;
@end


@implementation DTPrefsRegController

+ (NSSet*) keyPathsForValuesAffectingIcon {
	return [NSSet setWithObject:@"isRegistered"];
}
- (NSImage*)icon {
	if([self isRegistered])
		return [NSImage imageNamed:@"NSApplicationIcon"];
	else
		return [NSImage imageNamed:@"DropLicenseFile"];
}

+ (NSSet*) keyPathsForValuesAffectingTopString {
	return [NSSet setWithObject:@"isRegistered"];
}
- (NSString*)topString {
	if([self isRegistered])
		return NSLocalizedString(@"Licensed", @"status text in registration pane below icon");
	else
		return NSLocalizedString(@"Drop License File", @"status text in registration pane below icon");
}

- (BOOL)isRegistered {
	return IS_REGISTERED;
}

- (IBAction)browseToLicenseFile:(id)sender {
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setResolvesAliases:YES];
    [openPanel setPrompt:NSLocalizedString(@"Choose", NULL)];
    [openPanel setCanCreateDirectories:NO];
	[openPanel setRequiredFileType:@"net.decimus.dterm.license"];
	
    [openPanel beginSheetForDirectory:nil 
								 file:@""
								types:[NSArray arrayWithObject:@"net.decimus.dterm.license"]
					   modalForWindow:[[self view] window]
						modalDelegate:self 
					   didEndSelector:@selector(chooseLicensePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}

- (void)chooseLicensePanelDidEnd:(NSOpenPanel*)panel returnCode:(int)code contextInfo:(void*)contextInfo {
	if(code != NSOKButton)
		return;
	
	NSURL* licenseURL = [panel URL];
	[self acceptLicenseURL:licenseURL];
}

- (void)acceptLicenseURL:(NSURL*)licenseURL {
	NSData* regData = [NSData dataWithContentsOfURL:licenseURL];
	if(!regData) {
		NSBeep();
		return;
	}
	
	[self willChangeValueForKey:@"isRegistered"];
	[[NSUserDefaults standardUserDefaults] setObject:regData forKey:DTLicenseDataKey];
	[self didChangeValueForKey:@"isRegistered"];
}

- (IBAction)showLicense:(id)sender {
	[[NSApp delegate] showLicense:sender];
}

- (IBAction)purchase:(id)sender {
	DSLicenseAutoDLWindowController* wc = [DSLicenseAutoDLWindowController sharedWindowController];
	[[wc window] center];
	[wc showWindow:sender];
	
	[wc openStoreWebsite:sender];
}

@end
