//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "RTFWindowController.h"


@implementation RTFWindowController

@synthesize rtfPath;
@synthesize windowTitle;

- (id)initWithRTFFile:(NSString*)_rtfPath {
	if((self = [super initWithWindowNibName:@"RTFWindow"])) {
		self.rtfPath = _rtfPath;
		self.windowTitle = [[rtfPath lastPathComponent] stringByDeletingPathExtension];
	}
	
	return self;
}

@end
