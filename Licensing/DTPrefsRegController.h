//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.


@interface DTPrefsRegController : NSViewController {
	
}

@property (assign, readonly) NSImage* icon;
@property (assign, readonly) NSString* topString;
@property (readonly) BOOL isRegistered;

- (IBAction)showLicense:(id)sender;

- (IBAction)browseToLicenseFile:(id)sender;
- (IBAction)purchase:(id)sender;

- (void)acceptLicenseURL:(NSURL*)licenseURL;

@end
