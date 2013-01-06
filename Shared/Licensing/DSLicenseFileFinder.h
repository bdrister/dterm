//  Copyright (c) 2008-2010 Decimus Software, Inc. All rights reserved.

BOOL AskUserIfTheyWantToInstallLicenseFile(NSString* path);

@interface DSLicenseFileFinder : NSObject {
	NSMetadataQuery* query;
	NSSet* lastSeenResults;
	
	id delegate;	// non-retained
}

- (id)initWithUTI:(NSString*)uti delegate:(id)delegate;
- (void)stopQuery;

@end

@interface NSObject (LicenseFileFinderDelegate)
- (void)licenseFileFinder:(DSLicenseFileFinder*)lff foundLicense:(NSString*)path;
@end