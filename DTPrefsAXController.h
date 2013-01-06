//  Copyright (c) 2007-2011 Decimus Software, Inc. All rights reserved.


@interface DTPrefsAXController : NSViewController {
	BOOL axGeneralAccessEnabled;
}

@property (readonly) BOOL axAppTrusted;
@property (readonly) NSString* axTrustStatusString;
@property (readonly) BOOL axGeneralAccessEnabled;
@property (readonly) NSString* axGeneralAccessEnabledString;

- (void)recheckGeneralAXAccess;

#ifndef MAC_APP_STORE
- (IBAction)setAXTrusted:(id)sender;
#endif
- (IBAction)showUniversalAccessPrefPane:(id)sender;

@end
