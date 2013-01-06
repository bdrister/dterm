//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DSUtilities.h"

NSString* newUniqueID() {
	//unique random ID number for the doc
	CFUUIDRef myUUID = NULL;
	NSString *myUUIDString = NULL;
	
	myUUID = CFUUIDCreate(kCFAllocatorDefault);
	
	if(myUUID != NULL) {
		myUUIDString = (NSString*)CFUUIDCreateString(kCFAllocatorDefault, myUUID);
		CFRelease(myUUID);
	}
	
	return [myUUIDString autorelease];
}