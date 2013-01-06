//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DTResultsView.h"

#import "DTTermWindowController.h"

@implementation DTResultsView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)awakeFromNib {
	[[goPrevButton cell] setBackgroundStyle:NSBackgroundStyleDark];
	[[goNextButton cell] setBackgroundStyle:NSBackgroundStyleDark];
}

- (void)drawRect:(NSRect)rect {
	[[[NSColor whiteColor] colorWithAlphaComponent:0.7] setStroke];
	
	NSBezierPath* outlinePath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect([self bounds], 0.5, 0.5)
																xRadius:5.0 yRadius:5.0];
	[outlinePath stroke];
	
	NSPoint startPoint = NSMakePoint(0.0, [self bounds].size.height - 18.0);
	startPoint = [self convertPointToBase:startPoint];
	startPoint.y = floor(startPoint.y) + 0.5;
	startPoint = [self convertPointFromBase:startPoint];
	
	NSPoint endPoint = NSMakePoint([self bounds].size.width, startPoint.y);
	
	[NSBezierPath strokeLineFromPoint:startPoint
							  toPoint:endPoint];
}

- (BOOL)performKeyEquivalent:(NSEvent*)event {
	NSString* chars = [event charactersIgnoringModifiers];
	if([chars isEqualToString:@"c"] &&
	   (([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSControlKeyMask)) {
		[[[self window] windowController] cancelCurrentCommand:self];
		return YES;
	}
	return [super performKeyEquivalent:event];
}

#pragma mark accessibility support

- (BOOL)accessibilityIsIgnored {
	return NO;
}

- (id)accessibilityAttributeValue:(NSString*)attribute {
	if([attribute isEqualToString:NSAccessibilityRoleAttribute]) {
		return NSAccessibilityGroupRole;
	} else {
		return [super accessibilityAttributeValue:attribute];
	}
}

@end
