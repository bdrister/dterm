//  Copyright (c) 2008-2010 Decimus Software, Inc. All rights reserved.

#import "DTAntialiasControllableTextField.h"


@implementation DTAntialiasControllableTextField

@synthesize disableAntialiasing;

+ (void)initialize {
	[DTAntialiasControllableTextField exposeBinding:@"disableAntialiasing"];
}

- (void)awakeFromNib {
	[self bind:@"disableAntialiasing"
	  toObject:[NSUserDefaultsController sharedUserDefaultsController]
   withKeyPath:@"values.DTDisableAntialiasing"
	   options:[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithBool:NO], NSNullPlaceholderBindingOption,
				nil]];
}

- (void)setDisableAntialiasing:(BOOL)b {
	disableAntialiasing = b;
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)aRect {
    NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];
	
	if(disableAntialiasing) {
		[currentContext saveGraphicsState];
		[currentContext setShouldAntialias:NO];
	}
	
    [super drawRect:aRect];
	
	if(disableAntialiasing)
		[currentContext restoreGraphicsState];
}

@end
