//  DSAppleScriptUtilities.m
//  Copyright (c) 2008-2010 Decimus Software, Inc. All rights reserved.

#import "DSAppleScriptUtilities.h"


@implementation DSAppleScriptUtilities

+ (NSString*)stringFromAppleScript:(NSString*)source error:(NSDictionary**)error {
	NSAppleScript* appleScript = [[[NSAppleScript alloc] initWithSource:source] autorelease];
	
	NSAppleEventDescriptor* result = [appleScript executeAndReturnError:error];
	if(!result)
		return nil;
	
	return [result stringValue];
}

+ (BOOL)bringApplicationToFront:(NSString*)appName error:(NSDictionary**)error {
	NSString* source = [NSString stringWithFormat:@"tell application \"%@\" to activate", appName];
	
	NSAppleScript* appleScript = [[[NSAppleScript alloc] initWithSource:source] autorelease];
	
	NSAppleEventDescriptor* result = [appleScript executeAndReturnError:error];
	if(!result)
		return NO;
	
	return YES;
}

@end
