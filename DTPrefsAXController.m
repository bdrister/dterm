//  Copyright (c) 2007-2011 Decimus Software, Inc. All rights reserved.

#import "DTPrefsAXController.h"

#import "DTBlackRedStatusTransformer.h"


@interface DTPrefsAXController ()
@property (readwrite) BOOL axGeneralAccessEnabled;
@end


@implementation DTPrefsAXController

+ (void)initialize {
	DTBlackRedStatusTransformer* vt = [[DTBlackRedStatusTransformer alloc] init];
	[NSValueTransformer setValueTransformer:vt forName:@"DTBlackRedStatusTransformer"];
}

#pragma mark accessors

- (BOOL)axAppTrusted {
	return AXIsProcessTrusted();
}

+ (NSSet*) keyPathsForValuesAffectingAxTrustStatusString {
	return [NSSet setWithObject:@"axAppTrusted"];
}
- (NSString*)axTrustStatusString {
	if(self.axAppTrusted)
		return NSLocalizedString(@"trusted", @"Accessibility API trust status tag");
	else
		return NSLocalizedString(@"not trusted", @"Accessibility API trust status tag");
}

- (void)recheckGeneralAXAccess {
	self.axGeneralAccessEnabled = AXAPIEnabled();
}

@synthesize axGeneralAccessEnabled;

+ (NSSet*)keyPathsForValuesAffectingAxGeneralAccessEnabledString {
	return [NSSet setWithObjects:
	        @"axGeneralAccessEnabled",
	        nil];
}
- (NSString*)axGeneralAccessEnabledString {
	if(self.axGeneralAccessEnabled)
		return NSLocalizedString(@"enabled", @"Accessibility API enabledness status tag");
	else
		return NSLocalizedString(@"disabled", @"Accessibility API enabledness status tag");
}

#pragma mark actions

#ifndef MAC_APP_STORE
- (IBAction)setAXTrusted:(id)sender {
	const char* path = [[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"setaxtrusted"] fileSystemRepresentation];
	if(!path) {
		NSLog(@"Couldn't find setaxtrusted executable path (815DF095-F323-4FE8-9C7C-2548FBEC1C17)");
		NSBeep();
		return;
	}
	
	//create authorization right list
	AuthorizationItem myItem;
	myItem.name = kAuthorizationRightExecute;
	myItem.valueLength = strlen(path);
	myItem.value = (void*)path;
	myItem.flags = 0;
	AuthorizationRights myRights = {1, &myItem};
	
	//set flags
	AuthorizationFlags myFlags;
	myFlags = kAuthorizationFlagDefaults | 
	kAuthorizationFlagInteractionAllowed | 
	kAuthorizationFlagExtendRights;        
	
	//create authorization reference
	AuthorizationRef myAuthorizationRef = NULL;
	OSStatus myStatus;
	myStatus = AuthorizationCreate (&myRights, kAuthorizationEmptyEnvironment, 
									myFlags, &myAuthorizationRef);
	if(errAuthorizationCanceled == myStatus)
		return;
	if(errAuthorizationSuccess != myStatus) {
		NSLog(@"Couldn't create authorization (CE1B0C9A-4163-4829-BC69-97FE6B4E0C7A): %d", myStatus);
		NSBeep();
		return;
	}
	
	char* myPath = (char*)[[[NSBundle mainBundle] executablePath] fileSystemRepresentation];
	char* myArguments[] = { myPath, NULL };
	myStatus = AuthorizationExecuteWithPrivileges(myAuthorizationRef,
												  path, kAuthorizationFlagDefaults, 
												  myArguments, NULL);
	if(errAuthorizationSuccess != myStatus) {
		NSLog(@"AuthExecWithPrivs failed (8898E3BE-64FD-4D7B-852F-BF0596248E0B): %d", myStatus);
		AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
		NSBeep();
		return;
	}
	
	AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
	
	NSAlert* relaunchAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"Trust settings updated", @"relaunch alert title") 
											 defaultButton:NSLocalizedString(@"Relaunch now",  @"relaunch alert default button")
										   alternateButton:NSLocalizedString(@"Relaunch later", @"relaunch alert alternate button") 
											   otherButton:nil 
								 informativeTextWithFormat:NSLocalizedString(@"The new trust settings will take effect when DTerm is next launched.  Would you like to relaunch DTerm now?", @"relaunch alert text")];
	if([relaunchAlert runModal] == NSAlertDefaultReturn) {
		// This code borrowed from Sparkle, which was in turn borrowed from Allan Odgaard
		NSString *currentAppPath = [[NSBundle mainBundle] bundlePath];
		setenv("LAUNCH_PATH", [currentAppPath UTF8String], 1);
		system("/bin/bash -c '{ for (( i = 0; i < 3000 && $(echo $(/bin/ps -xp $PPID|/usr/bin/wc -l))-1; i++ )); do\n"
			   "    /bin/sleep .2;\n"
			   "  done\n"
			   "  if [[ $(/bin/ps -xp $PPID|/usr/bin/wc -l) -ne 2 ]]; then\n"
			   "    /bin/sleep 1.0;\n"
			   "    /usr/bin/open \"${LAUNCH_PATH}\"\n"
			   "  fi\n"
			   "} &>/dev/null &'");
		[NSApp terminate:self];
	}
}
#endif

- (IBAction)showUniversalAccessPrefPane:(id)sender {
//	@try {
//		NSString* scriptPath = [[NSBundle mainBundle] pathForResource:@"ShowUniversalAccessPrefs" ofType:@"scpt"];
//		NSTask* osascript = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/osascript" arguments:[NSArray arrayWithObject:scriptPath]];
//		[osascript waitUntilExit];
//	}
//	@catch (NSException* e) {
		[[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
//	}
}

@end
