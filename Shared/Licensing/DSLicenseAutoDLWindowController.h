//  Copyright (c) 2008-2010 Decimus Software, Inc. All rights reserved.


@interface DSLicenseAutoDLWindowController : NSWindowController {

}

+ (DSLicenseAutoDLWindowController*)sharedWindowController;

- (NSString*)applicationName;

- (IBAction)openStoreWebsite:(id)sender;
- (IBAction)checkForLicense:(id)sender;

@end
