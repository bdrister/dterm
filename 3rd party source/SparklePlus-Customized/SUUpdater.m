//
//  SUUpdater.m
//  Sparkle
//
//  Created by Andy Matuschak on 1/4/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//
// $Id: SUUpdater.m 51 2006-07-26 22:27:12Z atomicbird $
// $HeadURL: http://sparkleplus.googlecode.com/svn/tags/release-0.3/SUUpdater.m $

#import "SUUpdater.h"
#import "SUAppcast.h"
#import "SUAppcastItem.h"
#import "SUUnarchiver.h"
#import "SUUtilities.h"

#import "SUUpdateAlert.h"
#import "SUAutomaticUpdateAlert.h"
#import "SUStatusController.h"

#import "NSFileManager+Authentication.h"
#import "NSFileManager+Verification.h"
#import "NSApplication+AppCopies.h"

#import <stdio.h>
#import <sys/stat.h>
#import <unistd.h>
#import <signal.h>
#import <dirent.h>
#import <sys/sysctl.h>

@interface SUUpdater (Private)
- (void)checkForUpdatesAndNotify:(BOOL)verbosity;
- (void)showUpdateErrorAlertWithInfo:(NSString *)info;
- (NSTimeInterval)storedCheckInterval;
- (void)abandonUpdate;
- (IBAction)installAndRestart:sender;
@end

static NSDictionary *modelTranslation = nil;

@implementation SUUpdater

- init
{
	[super init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:@"NSApplicationDidFinishLaunchingNotification" object:NSApp];	

	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"SUModelTranslation" ofType:@"plist"];
	if (!path) // slight hack to resolve issues with running with in configurations
	{
		NSBundle *current = [NSBundle bundleForClass:[self class]];
		NSString *frameworkPath = [[[NSBundle mainBundle] sharedFrameworksPath] stringByAppendingFormat:@"/Sparkle.framework", [current bundleIdentifier]];
		NSBundle *framework = [NSBundle bundleWithPath:frameworkPath];
		path = [framework pathForResource:@"SUModelTranslation" ofType:@"plist"];
	}
	
	modelTranslation = [[NSDictionary alloc] initWithContentsOfFile:path];
	return self;
}

- (void)scheduleCheckWithInterval:(NSTimeInterval)interval
{
	if (checkTimer)
	{
		[checkTimer invalidate];
		checkTimer = nil;
	}
	
	checkInterval = interval;
	if (interval > 0)
		checkTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(checkForUpdatesInBackground) userInfo:nil repeats:YES];
}

- (void)scheduleCheckWithIntervalObject:(NSNumber *)interval
{
	[self scheduleCheckWithInterval:[interval doubleValue]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
	// If there's a scheduled interval, we see if it's been longer than that interval since the last
	// check. If so, we perform a startup check; if not, we don't.	
	if ([self storedCheckInterval])
	{
		NSTimeInterval interval = [self storedCheckInterval];
		NSDate *lastCheck = [[NSUserDefaults standardUserDefaults] objectForKey:SULastCheckTimeKey];
		if (!lastCheck) { lastCheck = [NSDate date]; }
		NSTimeInterval intervalSinceCheck = [[NSDate date] timeIntervalSinceDate:lastCheck];
		if (intervalSinceCheck < interval)
		{
			// Hasn't been long enough; schedule a check for the future.
			[self performSelector:@selector(checkForUpdatesInBackground) withObject:nil afterDelay:intervalSinceCheck];
			[self performSelector:@selector(scheduleCheckWithIntervalObject:) withObject:[NSNumber numberWithLong:interval] afterDelay:intervalSinceCheck];
		}
		else
		{
			[self scheduleCheckWithInterval:interval];
			[self checkForUpdatesInBackground];
		}
	}
	else
	{
		// There's no scheduled check, so let's see if we're supposed to check on startup.
		NSNumber *shouldCheckAtStartup = [[NSUserDefaults standardUserDefaults] objectForKey:SUCheckAtStartupKey];
		NSNumber *shouldSendProfileInfo = [[NSUserDefaults standardUserDefaults] objectForKey:SUSendProfileInfoKey];
		
		// not in prefs, but check Info.plist
		if (!shouldCheckAtStartup) {
			NSNumber *infoStartupValue = SUInfoValueForKey(SUCheckAtStartupKey);
			if (infoStartupValue)
			{
				shouldCheckAtStartup = infoStartupValue;
			}
		}
		if (!shouldSendProfileInfo) {
			NSNumber *infoSendProfileValue = SUInfoValueForKey(SUSendProfileInfoKey);
			if (infoSendProfileValue)
			{
				shouldSendProfileInfo = infoSendProfileValue;
			}
		}
		
		// If either one is still unspecified, ask the user what they think.
		if (!(shouldCheckAtStartup && shouldSendProfileInfo)) {
			// Setting this pref here has the effect of making the checkbox in the window on by default, but the user can still uncheck
			// it and their preference will be remembered next time.
			[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:SUSendProfileInfoKey];
			
			NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
			// if myBundle can't find it...  emulate other code by looking for the framework bundle the hard way.
			if (![myBundle loadNibFile:@"SUProfileInfo" externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"] withZone:nil]) {
				// OK, we'll do this the hard way
				NSString *frameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingFormat:@"/Sparkle.framework"];
				NSBundle *framework = [NSBundle bundleWithPath:frameworkPath];
				[framework loadNibFile:@"SUProfileInfo" externalNameTable:[NSDictionary dictionaryWithObject:self forKey:@"NSOwner"] withZone:nil];
			}
			if (profileMoreInfoView != nil) {
				[checkForUpdatesText setStringValue:[NSString stringWithFormat:SULocalizedString(@"Would you like %@ to check for updates on startup? If not, you can initiate the check manually from the application menu.", nil), SUHostAppDisplayName()]];
				[NSApp beginSheet:profileMoreInfoWindow
				   modalForWindow:nil
					modalDelegate:self
				   didEndSelector:@selector(profileInfoSheetDidEnd:returnCode:contextInfo:)
					  contextInfo:nil];
			} else {
				// OMFG!  Where's the nib?  Time to muddle through...  This is uglier but only serves as a fallback position if the nib's missing.
				shouldCheckAtStartup = [NSNumber numberWithBool:NSRunAlertPanel(SULocalizedString(@"Check for updates on startup?", nil), [NSString stringWithFormat:SULocalizedString(@"Would you like %@ to check for updates on startup? If not, you can initiate the check manually from the application menu.", nil), SUHostAppDisplayName()], SULocalizedString(@"Yes", nil), SULocalizedString(@"No", nil), nil) == NSAlertDefaultReturn];
				[[NSUserDefaults standardUserDefaults] setObject:shouldCheckAtStartup forKey:SUCheckAtStartupKey];
				shouldSendProfileInfo = [NSNumber numberWithBool:NSRunAlertPanel(SULocalizedString(@"Include anonymous system profile?", nil), [NSString stringWithFormat:SULocalizedString(@"Anonymous system profile information is used to help us plan future development work.", nil), SUHostAppDisplayName()], SULocalizedString(@"Yes", nil), SULocalizedString(@"No", nil), nil) == NSAlertDefaultReturn];
				[[NSUserDefaults standardUserDefaults] setObject:shouldSendProfileInfo forKey:SUSendProfileInfoKey];
				if ([shouldCheckAtStartup boolValue])
					[self checkForUpdatesInBackground];
			}
		}
	}
}

- (IBAction)closeProfileInfoSheet:(id)sender
{
	[profileMoreInfoWindow orderOut:sender];
	[NSApp endSheet:profileMoreInfoWindow returnCode:[sender tag]];
}

- (void)profileInfoSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	// SUSendProfileInfoKey will have been set through bindings, so don't bother with it here.
	if (returnCode == 1) {
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:SUCheckAtStartupKey];
	} else {
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:NO] forKey:SUCheckAtStartupKey];
	}
	NSNumber *shouldCheckAtStartup = [[NSUserDefaults standardUserDefaults] objectForKey:SUCheckAtStartupKey];
	if ([shouldCheckAtStartup boolValue])
		[self checkForUpdatesInBackground];
}

- (void)dealloc
{
	[updateItem release];
    [updateAlert release];
	
	[downloadPath release];
	[statusController release];
	[downloader release];
	
	if (checkTimer)
		[checkTimer invalidate];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)checkForUpdatesInBackground
{
	[self checkForUpdatesAndNotify:NO];
}

- (IBAction)checkForUpdates:sender
{
	[self checkForUpdatesAndNotify:YES]; // if we're coming from IB, then we want to be more verbose.
}

- (NSMutableArray *)systemProfileInformationArray
{
	// Gather profile information and append it to the URL.
	NSMutableArray *profileArray = [NSMutableArray array];
	NSArray *profileDictKeys = [NSArray arrayWithObjects:@"key",@"visibleKey",@"value",@"visibleValue",nil];
	int error = 0 ;
	int value = 0 ;
	unsigned long length = sizeof(value) ;
	
	// OS version (Apple recommends using SystemVersion.plist instead of Gestalt() here, don't ask me why).
	NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	NSString *osVersion = [systemVersion objectForKey:@"ProductVersion"];
	if (osVersion != nil)
		[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"osVersion",@"OS Version",osVersion,osVersion,nil] forKeys:profileDictKeys]];
	
	// CPU type (decoder info for values found here is in mach/machine.h)
	error = sysctlbyname("hw.cputype", &value, &length, NULL, 0);
	int cpuType = -1;
	if (error == 0) {
		cpuType = value;
		NSString *visibleCPUType;
		switch(value) {
			case 7:		visibleCPUType=@"Intel";	break;
			case 18:	visibleCPUType=@"PowerPC";	break;
			default:	visibleCPUType=@"Unknown";	break;
		}
		[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"cputype",@"CPU Type", [NSNumber numberWithInt:value], visibleCPUType,nil] forKeys:profileDictKeys]];
	}
	error = sysctlbyname("hw.cpusubtype", &value, &length, NULL, 0);
	if (error == 0) {
		NSString *visibleCPUSubType;
		if (cpuType == 7) {
			// Intel
			visibleCPUSubType = @"Intel";	// If anyone knows how to tell a Core Duo from a Core Solo, please email tph@atomicbird.com
		} else if (cpuType == 18) {
			// PowerPC
			switch(value) {
				case 9:					visibleCPUSubType=@"G3";	break;
				case 10:	case 11:	visibleCPUSubType=@"G4";	break;
				case 100:				visibleCPUSubType=@"G5";	break;
				default:				visibleCPUSubType=@"Other";	break;
			}
		} else {
			visibleCPUSubType = @"Other";
		}
		[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"cpusubtype",@"CPU Subtype", [NSNumber numberWithInt:value], visibleCPUSubType,nil] forKeys:profileDictKeys]];
	}
	error = sysctlbyname("hw.model", NULL, &length, NULL, 0);
	if (error == 0) {
		char *cpuModel;
		cpuModel = (char *)malloc(sizeof(char) * length);
		error = sysctlbyname("hw.model", cpuModel, &length, NULL, 0);
		if (error == 0) {
			NSString *rawModelName = [NSString stringWithUTF8String:cpuModel];
			NSString *visibleModelName = [modelTranslation objectForKey:rawModelName];
			if (visibleModelName == nil)
				visibleModelName = rawModelName;
			[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"model",@"Mac Model", rawModelName, visibleModelName, nil] forKeys:profileDictKeys]];
		}
		if (cpuModel != NULL)
			free(cpuModel);
	}
	
	// Number of CPUs
	error = sysctlbyname("hw.ncpu", &value, &length, NULL, 0);
	if (error == 0)
		[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"ncpu",@"Number of CPUs", [NSNumber numberWithInt:value], [NSNumber numberWithInt:value],nil] forKeys:profileDictKeys]];
	
	// User preferred language
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	NSArray *languages = [defs objectForKey:@"AppleLanguages"];
	if (languages && ([languages count] > 0))
		[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"lang",@"Preferred Language", [languages objectAtIndex:0], [languages objectAtIndex:0],nil] forKeys:profileDictKeys]];
	
	// Application sending the request
	NSString *appName = [SUInfoValueForKey(@"CFBundleName") stringByAppendingPathExtension:@"app"];
	if (appName)
		[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"appName",@"Application Name", appName, appName,nil] forKeys:profileDictKeys]];
	NSString *appVersion = SUInfoValueForKey(@"CFBundleVersion");
	if (appVersion)
		[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"appVersion",@"Application Version", appVersion, appVersion,nil] forKeys:profileDictKeys]];
	
	// Number of displays?
	// CPU speed
	OSErr err;
	SInt32 gestaltInfo;
	err = Gestalt(gestaltProcClkSpeedMHz,&gestaltInfo);
	if (err == noErr)
		[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"cpuFreqMHz",@"CPU Speed (MHz)", [NSNumber numberWithInt:gestaltInfo], [NSNumber numberWithInt:gestaltInfo],nil] forKeys:profileDictKeys]];
	
	// amount of RAM
	err = Gestalt(gestaltPhysicalRAMSizeInMegabytes,&gestaltInfo);
	if (err == noErr)
		[profileArray addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"ramMB",@"Memory (MB)", [NSNumber numberWithInt:gestaltInfo], [NSNumber numberWithInt:gestaltInfo],nil] forKeys:profileDictKeys]];
	
	// ask the delegate if there's anything more
	if ([delegate respondsToSelector:@selector(updaterCustomizeProfileInfo:)]) {
		profileArray = [delegate updaterCustomizeProfileInfo:profileArray];
	}
	return profileArray;
}

- (NSString *)appendProfileInfoToURLString:(NSString *)appcastString
{
	NSMutableArray *profileInfo = [NSMutableArray array];
	NSArray *profileArray = [self systemProfileInformationArray];
	NSEnumerator *profileInfoEnumerator = [profileArray objectEnumerator];
	NSDictionary *currentProfileInfo;
	while ((currentProfileInfo = [profileInfoEnumerator nextObject])) {
		[profileInfo addObject:[NSString stringWithFormat:@"%@=%@", [currentProfileInfo objectForKey:@"key"], [currentProfileInfo objectForKey:@"value"]]];
	}
	NSString *appcastStringWithProfile = [NSString stringWithFormat:@"%@?%@", appcastString, [profileInfo componentsJoinedByString:@"&"]];
	// Clean it up so it's a valid URL
	return [appcastStringWithProfile stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	if ([item action] == @selector(checkForUpdates:))
		return ! updateInProgress;
	return [super validateMenuItem:item];
}

// If the verbosity flag is YES, Sparkle will say when it can't reach the server and when there's no new update.
// This is generally useful for a menu item--when the check is explicitly invoked.
- (void)checkForUpdatesAndNotify:(BOOL)verbosity
{	
	if (updateInProgress)
	{
		// This block will probably never be called, since -validateMenuItem should prevent this method
		// being called when an update is in progress, but I left it in as a last-ditch prevention measure. - tph@atomicbird.com
		if (verbosity)
		{
			NSBeep();
			if ([[statusController window] isVisible])
				[statusController showWindow:self];
			else if ([[updateAlert window] isVisible])
				[updateAlert showWindow:self];
			else
				[self showUpdateErrorAlertWithInfo:SULocalizedString(@"An update is already in progress!", nil)];
		}
		return;
	}
	verbose = verbosity;
	updateInProgress = YES;
	
	// A value in the user defaults overrides one in the Info.plist (so preferences panels can be created wherein users choose between beta / release feeds).
	NSString *appcastString = [[NSUserDefaults standardUserDefaults] objectForKey:SUFeedURLKey];
	if (!appcastString)
		appcastString = SUInfoValueForKey(SUFeedURLKey);
	if (!appcastString) { [NSException raise:@"SUNoFeedURL" format:@"No feed URL is specified in the Info.plist or the user defaults!"]; }
	
	if ([delegate respondsToSelector:@selector(updaterShouldSendProfileInfo)]) {
		// If the delegate implements this method, do whatever it says here.
		if ([delegate updaterShouldSendProfileInfo]) {
			appcastString = [self appendProfileInfoToURLString:appcastString];
		}
	} else {
		// If the delegate doesn't implement that method, use the user pref.
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:SUSendProfileInfoKey] boolValue]) {
			appcastString = [self appendProfileInfoToURLString:appcastString];
		}
	}
	SUAppcast *appcast = [[SUAppcast alloc] init];
	[appcast setDelegate:self];
	[appcast fetchAppcastFromURL:[NSURL URLWithString:appcastString]];
}

- (BOOL)automaticallyUpdates
{
	if (![SUInfoValueForKey(SUAllowsAutomaticUpdatesKey) boolValue] && [SUInfoValueForKey(SUAllowsAutomaticUpdatesKey) boolValue]) { return NO; }
	if (![[NSUserDefaults standardUserDefaults] objectForKey:SUAutomaticallyUpdateKey]) { return NO; } // defaults to NO
	return [[[NSUserDefaults standardUserDefaults] objectForKey:SUAutomaticallyUpdateKey] boolValue];
}

- (BOOL)isAutomaticallyUpdating
{
	return [self automaticallyUpdates] && !verbose;
}

- (void)showUpdateErrorAlertWithInfo:(NSString *)info
{
	if ([self isAutomaticallyUpdating]) { return; }
	NSRunAlertPanel(SULocalizedString(@"Update Error!", nil), info, NSLocalizedString(@"Cancel", nil), nil, nil);
}

- (NSTimeInterval)storedCheckInterval
{
	// Returns the scheduled check interval stored in the user defaults / info.plist. User defaults override Info.plist.
	if ([[NSUserDefaults standardUserDefaults] objectForKey:SUScheduledCheckIntervalKey])
	{
		long interval = [[[NSUserDefaults standardUserDefaults] objectForKey:SUScheduledCheckIntervalKey] longValue];
		if (interval > 0)
			return interval;
	}
	if (SUInfoValueForKey(SUScheduledCheckIntervalKey))
		return [SUInfoValueForKey(SUScheduledCheckIntervalKey) longValue];
	return 0;
}

- (void)beginDownload
{
	if (![self isAutomaticallyUpdating])
	{
		statusController = [[SUStatusController alloc] init];
		[statusController beginActionWithTitle:SULocalizedString(@"Downloading update...", nil) maxProgressValue:0 statusText:nil];
		[statusController setButtonTitle:NSLocalizedString(@"Cancel", nil) target:self action:@selector(cancelDownload:) isDefault:NO];
		[statusController showWindow:self];
	}
	
	downloader = [[NSURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:[updateItem fileURL]] delegate:self];	
}

- (void)remindMeLater
{
	// Clear out the skipped version so the dialog will actually come back if it was already skipped.
	[[NSUserDefaults standardUserDefaults] setObject:nil forKey:SUSkippedVersionKey];
	
	if (checkInterval)
		[self scheduleCheckWithInterval:checkInterval];
	else
	{
		// If the host hasn't provided a check interval, we'll use 30 minutes.
		[self scheduleCheckWithInterval:30 * 60];
	}
}

- (void)updateAlert:(SUUpdateAlert *)alert finishedWithChoice:(SUUpdateAlertChoice)choice
{
	[alert release];
	switch (choice)
	{
		case SUInstallUpdateChoice:
			// Clear out the skipped version so the dialog will come back if the download fails.
			[[NSUserDefaults standardUserDefaults] setObject:nil forKey:SUSkippedVersionKey];
			[self beginDownload];
			break;
			
		case SURemindMeLaterChoice:
			updateInProgress = NO;
			[self remindMeLater];
			break;
			
		case SUSkipThisVersionChoice:
			updateInProgress = NO;
			[[NSUserDefaults standardUserDefaults] setObject:[updateItem fileVersion] forKey:SUSkippedVersionKey];
			break;
	}			
}

- (void)showUpdatePanel
{
	updateAlert = [[SUUpdateAlert alloc] initWithAppcastItem:updateItem];
	[updateAlert setDelegate:self];
	[updateAlert showWindow:self];
}

- (void)appcastDidFailToLoad:(SUAppcast *)ac
{
	[ac autorelease];
	updateInProgress = NO;
	if (verbose)
		[self showUpdateErrorAlertWithInfo:SULocalizedString(@"An error occurred in retrieving update information; are you connected to the internet? Please try again later.", nil)];
}

// Override this to change the new version comparison logic!
- (BOOL)newVersionAvailable
{
	return SUStandardVersionComparison([updateItem fileVersion], SUHostAppVersion()) == NSOrderedAscending;
	// Want straight-up string comparison like Sparkle 1.0b3 and earlier? Uncomment the line below and comment the one above.
	// return ![SUHostAppVersion() isEqualToString:[updateItem fileVersion]];
}

- (void)appcastDidFinishLoading:(SUAppcast *)ac
{
	@try
	{
		if (!ac) { [NSException raise:@"SUAppcastException" format:@"Couldn't get a valid appcast from the server."]; }

		updateItem = [[ac newestItem] retain];
		[ac autorelease];

		// Record the time of the check for host app use and for interval checks on startup.
		[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:SULastCheckTimeKey];

		if (![updateItem fileVersion])
		{
			[NSException raise:@"SUAppcastException" format:@"Can't extract a version string from the appcast feed. The filenames should look like YourApp_1.5.tgz, where 1.5 is the version number."];
		}

		if (!verbose && [[[NSUserDefaults standardUserDefaults] objectForKey:SUSkippedVersionKey] isEqualToString:[updateItem fileVersion]]) { updateInProgress = NO; return; }

		if ([self newVersionAvailable])
		{
			if (checkTimer)	// There's a new version! Let's disable the automated checking timer unless the user cancels.
			{
				[checkTimer invalidate];
				checkTimer = nil;
			}
			
			if ([self isAutomaticallyUpdating])
			{
				[self beginDownload];
			}
			else
			{
				[self showUpdatePanel];
			}
		}
		else
		{
			if (verbose) // We only notify on no new version when we're being verbose.
			{
				NSRunAlertPanel(SULocalizedString(@"You're up to date!", nil), [NSString stringWithFormat:SULocalizedString(@"%@ %@ is currently the newest version available.", nil), SUHostAppDisplayName(), SUHostAppVersionString()], NSLocalizedString(@"OK", nil), nil, nil);
			}
			updateInProgress = NO;
		}
	}
	@catch (NSException *e)
	{
		NSLog(@"%@", [e reason]);
		updateInProgress = NO;
		if (verbose)
			[self showUpdateErrorAlertWithInfo:SULocalizedString(@"An error occurred in retrieving update information. Please try again later.", nil)];
	}
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response
{
	[statusController setMaxProgressValue:[response expectedContentLength]];
}

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)name
{
	// If name ends in .txt, the server probably has a stupid MIME configuration. We'll give
	// the developer the benefit of the doubt and chop that off.
	if ([[name pathExtension] isEqualToString:@"txt"])
		name = [name stringByDeletingPathExtension];
	
	// We create a temporary directory in /tmp and stick the file there.
	NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
	BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:tempDir attributes:nil];
	if (!success)
	{
		[NSException raise:@"SUFailTmpWrite" format:@"Couldn't create temporary directory in /tmp"];
		[download cancel];
		[download release];
	}
	
	[downloadPath autorelease];
	downloadPath = [[tempDir stringByAppendingPathComponent:name] retain];
	[download setDestination:downloadPath allowOverwrite:YES];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length
{
	[statusController setProgressValue:[statusController progressValue] + length];
	[statusController setStatusText:[NSString stringWithFormat:SULocalizedString(@"%.0lfk of %.0lfk", nil), [statusController progressValue] / 1024.0, [statusController maxProgressValue] / 1024.0]];
}

- (void)unarchiver:(SUUnarchiver *)ua extractedLength:(long)length
{
	if ([self isAutomaticallyUpdating]) { return; }
	if ([statusController maxProgressValue] == 0)
		[statusController setMaxProgressValue:[[[[NSFileManager defaultManager] fileAttributesAtPath:downloadPath traverseLink:NO] objectForKey:NSFileSize] longValue]];
	[statusController setProgressValue:[statusController progressValue] + length];
}

- (void)unarchiverDidFinish:(SUUnarchiver *)ua
{
	[ua autorelease];
	
	if ([self isAutomaticallyUpdating])
	{
		[self installAndRestart:self];
	}
	else
	{
		[statusController beginActionWithTitle:SULocalizedString(@"Ready to install!", nil) maxProgressValue:1 statusText:nil];
		[statusController setProgressValue:1]; // fill the bar
		[statusController setButtonTitle:SULocalizedString(@"Install and Relaunch", nil) target:self action:@selector(installAndRestart:) isDefault:YES];
		[NSApp requestUserAttention:NSInformationalRequest];
	}
}

- (void)unarchiverDidFail:(SUUnarchiver *)ua
{
	[ua autorelease];
	[self showUpdateErrorAlertWithInfo:SULocalizedString(@"An error occurred while extracting the archive. Please try again later.", nil)];
	[self abandonUpdate];
}

- (void)extractUpdate
{
	// Now we have to extract the downloaded archive.
	if (![self isAutomaticallyUpdating])
		[statusController beginActionWithTitle:SULocalizedString(@"Extracting update...", nil) maxProgressValue:0 statusText:nil];
	
	@try 
	{
		// If the developer's provided a sparkle:md5Hash attribute on the enclosure, let's verify that.
		if ([updateItem MD5Sum] && ![[NSFileManager defaultManager] validatePath:downloadPath withMD5Hash:[updateItem MD5Sum]])
		{
			[NSException raise:@"SUUnarchiveException" format:@"MD5 verification of the update archive failed."];
		}
		
		// DSA verification, if activated by the developer
		if ([SUInfoValueForKey(SUExpectsDSASignatureKey) boolValue])
		{
			NSString *dsaSignature = [updateItem DSASignature];
			if (![[NSFileManager defaultManager] validatePath:downloadPath withEncodedDSASignature:dsaSignature])
			{
				[NSException raise:@"SUUnarchiveException" format:@"DSA verification of the update archive failed."];
			}
		}
		
		SUUnarchiver *unarchiver = [[SUUnarchiver alloc] init];
		[unarchiver setDelegate:self];
		[unarchiver unarchivePath:downloadPath]; // asynchronous extraction!
	}
	@catch(NSException *e) {
		NSLog(@"%@", [e reason]);
		[self showUpdateErrorAlertWithInfo:SULocalizedString(@"An error occurred while extracting the archive. Please try again later.", nil)];
		[self abandonUpdate];
	}	
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
	[download release];
	downloader = nil;
	[self extractUpdate];
}

- (void)abandonUpdate
{
	[updateItem release];
	[statusController close];
	[statusController release];
	updateInProgress = NO;	
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	[self abandonUpdate];
	
	NSLog(@"Download error: %@", [error localizedDescription]);
	[self showUpdateErrorAlertWithInfo:SULocalizedString(@"An error occurred while trying to download the file. Please try again later.", nil)];
}

- (IBAction)installAndRestart:sender
{
	NSString *currentAppPath = [[NSBundle mainBundle] bundlePath];
	NSString *newAppDownloadPath = [[downloadPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[SUInfoValueForKey(@"CFBundleName") stringByAppendingPathExtension:@"app"]];
	@try 
	{
		if (![self isAutomaticallyUpdating])
		{
			[statusController beginActionWithTitle:SULocalizedString(@"Installing update...", nil) maxProgressValue:0 statusText:nil];
			[statusController setButtonEnabled:NO];
			
			// We have to wait for the UI to update.
			NSEvent *event;
			while((event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES]))
				[NSApp sendEvent:event];			
		}
		
		// We assume that the archive will contain a file named {CFBundleName}.app
		// (where, obviously, CFBundleName comes from Info.plist)
		if (!SUInfoValueForKey(@"CFBundleName")) { [NSException raise:@"SUInstallException" format:@"This application has no CFBundleName! This key must be set to the application's name."]; }
		
		// Search subdirectories for the application
		NSString *file, *appName = [currentAppPath lastPathComponent];
		NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:[downloadPath stringByDeletingLastPathComponent]];
		while ((file = [dirEnum nextObject]))
		{
			// Some DMGs have symlinks into /Applications! That's no good!
			if ([file isEqualToString:@"/Applications"])
				[dirEnum skipDescendents];
			NSString* lastPathComponent = [file lastPathComponent];
			if ([lastPathComponent isEqualToString:appName]) {
				newAppDownloadPath = [[downloadPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:file];
				break;
			}
		}
		
		if (!newAppDownloadPath || ![[NSFileManager defaultManager] fileExistsAtPath:newAppDownloadPath])
		{
			[NSException raise:@"SUInstallException" format:@"The update archive didn't contain an application with the proper name: %@. Remember, the updated app's file name must be identical to {CFBundleName}.app", [SUInfoValueForKey(@"CFBundleName") stringByAppendingPathExtension:@"app"]];
		}
	}
	@catch(NSException *e) 
	{
		NSLog(@"%@", [e reason]);
		[self showUpdateErrorAlertWithInfo:SULocalizedString(@"An error occurred during installation. Please try again later.", nil)];
		[self abandonUpdate];		
	}
	
	if ([self isAutomaticallyUpdating]) // Don't do authentication if we're automatically updating; that'd be surprising.
	{
		NSInteger tag = 0;
		BOOL result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[currentAppPath stringByDeletingLastPathComponent] destination:@"" files:[NSArray arrayWithObject:[currentAppPath lastPathComponent]] tag:&tag];
		result &= [[NSFileManager defaultManager] movePath:newAppDownloadPath toPath:currentAppPath handler:nil];
		if (!result)
		{
			[self abandonUpdate];
			return;
		}
	}
	else // But if we're updating by the action of the user, do an authenticated move.
	{
		// Outside of the @try block because we want to be a little more informative on this error.
		if (![[NSFileManager defaultManager] movePathWithAuthentication:newAppDownloadPath toPath:currentAppPath])
		{
			[self showUpdateErrorAlertWithInfo:[NSString stringWithFormat:SULocalizedString(@"%@ does not have permission to write to the application's directory! Are you running off a disk image? If not, ask your system administrator for help.", nil), SUHostAppDisplayName()]];
			[self abandonUpdate];
			return;
		}
	}
		
	// Prompt for permission to restart if we're automatically updating.
	if ([self isAutomaticallyUpdating])
	{
		SUAutomaticUpdateAlert *alert = [[SUAutomaticUpdateAlert alloc] initWithAppcastItem:updateItem];
		if ([NSApp runModalForWindow:[alert window]] == NSAlertAlternateReturn)
		{
			[alert release];
			return;
		}
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SUUpdaterWillRestartNotification object:self];

	// Thanks to Allan Odgaard for this restart code, which is much more clever than mine was.
	setenv("LAUNCH_PATH", [currentAppPath UTF8String], 1);
	setenv("TEMP_FOLDER", [[downloadPath stringByDeletingLastPathComponent] UTF8String], 1); // delete the temp stuff after it's all over
	system("/bin/bash -c '{ for (( i = 0; i < 3000 && $(echo $(/bin/ps -xp $PPID|/usr/bin/wc -l))-1; i++ )); do\n"
		   "    /bin/sleep .2;\n"
		   "  done\n"
		   "  if [[ $(/bin/ps -xp $PPID|/usr/bin/wc -l) -ne 2 ]]; then\n"
		   "    /usr/bin/open \"${LAUNCH_PATH}\"\n"
		   "  fi\n"
		   "  rm -rf \"${TEMP_FOLDER}\"\n"
		   "} &>/dev/null &'");
	[NSApp terminate:self];	
}

- (IBAction)cancelDownload:sender
{
	if (downloader)
	{
		[downloader cancel];
		[downloader release];
	}
	[self abandonUpdate];
	
	if (checkInterval)
	{
		[self scheduleCheckWithInterval:checkInterval];
	}
}

- (void)setDelegate:del
{
	delegate = del;
}

// Update the GUI when the user asks to show/hide more info about the profile report.
- (void)setMoreInfoVisible:(BOOL)newFlagValue
{
	moreInfoVisible = newFlagValue;
	NSView *contentView = [profileMoreInfoWindow contentView];
	NSRect contentViewFrame = [contentView frame];
	NSRect windowFrame = [profileMoreInfoWindow frame];
	
	NSRect profileMoreInfoViewFrame = [profileMoreInfoView frame];
	NSRect profileMoreInfoButtonFrame = [profileMoreInfoButton frame];
	
	if (moreInfoVisible) {
		// Add the subview
		contentViewFrame.size.height += profileMoreInfoViewFrame.size.height;
		profileMoreInfoViewFrame.origin.y = profileMoreInfoButtonFrame.origin.y - profileMoreInfoViewFrame.size.height;
		
		windowFrame.size.height += profileMoreInfoViewFrame.size.height;
		windowFrame.origin.y -= profileMoreInfoViewFrame.size.height;
		
		[profileMoreInfoView setFrame:profileMoreInfoViewFrame];
		[profileMoreInfoView setHidden:YES];
		[contentView addSubview:profileMoreInfoView
					 positioned:NSWindowBelow
					 relativeTo:profileMoreInfoButton];
	} else {
		// Remove the subview
		[profileMoreInfoView setHidden:NO];
		[profileMoreInfoView removeFromSuperview];
		contentViewFrame.size.height -= profileMoreInfoViewFrame.size.height;
		
		windowFrame.size.height -= profileMoreInfoViewFrame.size.height;
		windowFrame.origin.y += profileMoreInfoViewFrame.size.height;
	}
	[profileMoreInfoWindow setFrame:windowFrame display:YES animate:YES];
	[contentView setFrame:contentViewFrame];
	[contentView setNeedsDisplay:YES];
	[profileMoreInfoView setHidden:(!moreInfoVisible)];
}
@end