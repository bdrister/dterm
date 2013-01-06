//  Copyright (c) 2008-2010 Decimus Software, Inc. All rights reserved.

#import "DSLicenseAutoDLWindowController.h"

#import <openssl/sha.h>

#import "DSUtilities.h"

// From GetPrimaryMACAddress.m
extern NSString* PrimaryMACAddress();

@interface DSLicenseAutoDLWindowController (DSPrivate)
- (NSString*)autoDLID;
@end

@interface NSObject (DSAppDelegateLicenseSupport)
- (BOOL)installLicenseFromData:(NSData*)licData;
- (NSString*)storeProductID;
@end


@implementation DSLicenseAutoDLWindowController

+ (DSLicenseAutoDLWindowController*)sharedWindowController {
	static DSLicenseAutoDLWindowController* sharedWindowController = nil;
	
	if(!sharedWindowController)
		sharedWindowController = [[DSLicenseAutoDLWindowController alloc] init];
	
	return sharedWindowController;
}

- (id)init {
	if((self = [super initWithWindowNibName:@"LicensingAutoDL"])) {
		
	}
	
	return self;
}

- (NSString*)applicationName {
	return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
}

- (IBAction)openStoreWebsite:(id)sender {
	NSString* urlString = [NSString stringWithFormat:@"https://store.decimus.net/autodl.php?autoDL=%@",
						   [self autoDLID]];
	NSURL* url = [NSURL URLWithString:urlString];
	
	[[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)checkForLicense:(id)sender {
	id appDelegate = [NSApp delegate];
	if(![appDelegate respondsToSelector:@selector(installLicenseFromData:)] ||
	   ![appDelegate respondsToSelector:@selector(storeProductID)]) {
		[[NSAlert alertWithMessageText:NSLocalizedString(@"Internal Error", nil)
						 defaultButton:@"OK"
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:@"App delegate couldn't handle license data.  Please notify support@decimus.net."]
		 runModal];
		return;
	}
	
	NSString* urlString = [NSString stringWithFormat:@"https://store.decimus.net/util/autoDL.php?autoDL=%@&product=%@",
						   [self autoDLID],
						   [appDelegate storeProductID]];
	NSURL* url = [NSURL URLWithString:urlString];
	
	NSData* data = [NSData dataWithContentsOfURL:url];
	if(!data) {
		[[NSAlert alertWithMessageText:NSLocalizedString(@"Unable to check for license", nil)
						 defaultButton:@"OK"
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:NSLocalizedString(@"The server may not be responding, or you may not be connected to the internet.  Please check your connection and try again later.", nil)]
		 runModal];
		return;
	}
	
	id result = [NSPropertyListSerialization propertyListFromData:data
												 mutabilityOption:NSPropertyListImmutable
														   format:nil
												 errorDescription:nil];
	
	
	if([result isKindOfClass:[NSString class]]) {
		// Strings are messages from the server, usually error messages
		[[NSAlert alertWithMessageText:NSLocalizedString(@"Message from server", nil)
						 defaultButton:@"OK"
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:@"%@", result]
		 runModal];
	} else if([result isKindOfClass:[NSDictionary class]]) {
		// Dictionaries are presumed to be licenses
		// Ask the app delegate if it's a good license
		if([appDelegate installLicenseFromData:data])
			[self close];
	} else {
		[[NSAlert alertWithMessageText:NSLocalizedString(@"Unknown response received", nil)
						 defaultButton:@"OK"
					   alternateButton:nil
						   otherButton:nil
			 informativeTextWithFormat:NSLocalizedString(@"We couldn't understand the response from the server.  Make sure you are running the most recent version of %@.", nil), [self applicationName]]
		 runModal];
	}
	
	// TODO: check the result for being a valid license, or a message from the server
	//NSLog(@"Got result %@", result);
}

#pragma mark private methods

- (NSString*)autoDLID {
	NSString* rawID = nil;
	
	// Try serial number, first
	io_service_t    platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
																 IOServiceMatching("IOPlatformExpertDevice"));
	if(platformExpert) {
		rawID = (NSString*)IORegistryEntryCreateCFProperty(platformExpert,
														   CFSTR(kIOPlatformSerialNumberKey),
														   kCFAllocatorDefault, 0);
		[rawID autorelease];
		
		IOObjectRelease(platformExpert);
	}
	
	// Try primary MAC next
	if(!rawID) {
		rawID = PrimaryMACAddress();
	}
	
	// If all else fails, just make a UUID
	// Not reproducible, but at least it's something
	if(!rawID) {
		rawID = newUniqueID();
	}
	
	// SHA hash and return it
	NSData* idData = [rawID dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char hash[SHA_DIGEST_LENGTH];
	SHA1([idData bytes], [idData length], hash);
	
	// Convert hash to string
	NSMutableString* hashedString = [NSMutableString stringWithCapacity:(SHA_DIGEST_LENGTH*2)];
	for(unsigned i=0; i<SHA_DIGEST_LENGTH; i++) {
		[hashedString appendFormat:@"%02x", hash[i]];
	}
	
	return hashedString;
}

@end
