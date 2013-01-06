//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DTRegDropBox.h"

#import "DTPrefsRegController.h"
#import "DTPrefsWindowController.h"
#import "Licensing.h"

@implementation DTRegDropBox

- (void)awakeFromNib {
	[self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil]];
	
	for(id subview in [self subviews]) {
		if([subview respondsToSelector:@selector(setEditable:)])
			[subview setEditable:NO];
	}
}

NSURL* urlFromPasteboard(NSPasteboard* pboard) {
	NSURL* fileURL = [NSURL URLFromPasteboard:pboard];
	
	if(!fileURL && [[pboard types] containsObject:NSFilenamesPboardType]) {
        NSArray* files = [pboard propertyListForType:NSFilenamesPboardType];
		if([files count]) {
			fileURL = [NSURL fileURLWithPath:[files objectAtIndex:0]];
		}
    }
	
	if(fileURL) {
		if(![[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]])
			return nil;
		
		FSRef fsRef;
		if(!CFURLGetFSRef((CFURLRef)fileURL, &fsRef))
			return nil;
		
		CFTypeRef outValue;
		OSStatus err = LSCopyItemAttribute(&fsRef, kLSRolesAll, kLSItemContentType, &outValue);
		if(outValue)
			CFMakeCollectable(outValue);
		if(noErr != err)
			return nil;
		
		if(kCFCompareEqualTo == CFStringCompare(outValue, CFSTR("net.decimus.dterm.license"), kCFCompareCaseInsensitive))
			return fileURL;
	}
	
	return nil;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	if(IS_REGISTERED)
		return NSDragOperationNone;
	
	NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	if(!(sourceDragMask & NSDragOperationLink))
		return NSDragOperationNone;
		
    NSPasteboard* pboard = [sender draggingPasteboard];
	if(!urlFromPasteboard(pboard))
		return NSDragOperationNone;
	
	return NSDragOperationLink;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    if(!([sender draggingSourceOperationMask] & NSDragOperationLink))
		return NO;
	
    NSPasteboard* pboard = [sender draggingPasteboard];
	NSURL* fileURL = urlFromPasteboard(pboard);
	if(!fileURL)
		return NO;
	
	DTPrefsWindowController* wc = [[self window] windowController];
	[wc.regPrefsViewController acceptLicenseURL:fileURL];
	
	return YES;
}


@end
