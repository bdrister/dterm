//  Copyright (c) 2008-2010 Decimus Software, Inc. All rights reserved.


#import "DSLicenseFileFinder.h"

BOOL AskUserIfTheyWantToInstallLicenseFile(NSString* path) {
	NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	
	NSAlert* alert = [NSAlert alertWithMessageText:NSLocalizedString(@"License file found", nil)
									 defaultButton:@"Open"
								   alternateButton:@"Cancel"
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"%@ found a license file named '%@'; would you like %@ to automatically install it for you?", nil),
					  appName, [path lastPathComponent], appName];
	return [alert runModal] == NSAlertDefaultReturn;
}

@implementation DSLicenseFileFinder

- (id)initWithUTI:(NSString*)uti delegate:(id)del {
	if((self = [super init])) {
		delegate = del;
		lastSeenResults = [[NSSet alloc] init];
		
		query = [[NSMetadataQuery alloc] init];
		//[query setNotificationBatchingInterval:5.0];
		[query setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:(id)kMDItemFSName ascending:YES] autorelease]]];
		[query setPredicate:[NSPredicate predicateWithFormat: @"kMDItemContentType == %@", uti]];
		
		// setup our Spotlight notifications
        NSNotificationCenter *nf = [NSNotificationCenter defaultCenter];
        [nf addObserver:self selector:@selector(queryNotification:) name:nil object:query];
		
		[query startQuery];
	}
	
	return self;
}

- (void)queryNotification:(NSNotification*)note {
    [query disableUpdates];
	NSSet* newResults = [NSSet setWithArray:[query valueForKeyPath:@"results.kMDItemPath"]];
	[query enableUpdates];
	
	if([delegate respondsToSelector:@selector(licenseFileFinder:foundLicense:)]) {
		NSEnumerator* newPathsEnumerator = [newResults objectEnumerator];
		NSString* newPath;
		while((newPath = [newPathsEnumerator nextObject])) {
			if(![lastSeenResults containsObject:newPath])
				[delegate licenseFileFinder:self foundLicense:newPath];
		}
	}
	
	[lastSeenResults release];
	lastSeenResults = [newResults retain];
}

- (void)stopQuery {
	[query stopQuery];
	[query release]; query = nil;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[query release];
	[lastSeenResults release];
	
	[super dealloc];
}

@end
