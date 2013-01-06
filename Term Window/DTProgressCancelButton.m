//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DTProgressCancelButton.h"


@interface DTProgressCancelButton ()
- (void)updateImageForMouseInside:(BOOL)inside;
- (void)loadAnimImages;
- (void)updateAnimation:(NSTimer*)timer;
@end

@implementation DTProgressCancelButton

- (void)awakeFromNib {
	[[self cell] setBackgroundStyle:NSBackgroundStyleDark];
}

#pragma mark Rollover management

// NSImageNameStopProgressFreestandingTemplate

- (void)setHidden:(BOOL)hidden {
	BOOL wasHidden = [self isHiddenOrHasHiddenAncestor];
	[super setHidden:hidden];
	
	if(wasHidden == hidden)
		return;
	
	[self viewDidMoveToWindow];
	
	if(hidden) {
		// Now hiding; stop animation
		[animationTimer invalidate];
		animationTimer = nil;
	} else {
		if(!animImages)
			[self loadAnimImages];
		
		nextAnimImg = 0;
		if(!animationTimer)
			animationTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0/[animImages count])
															  target:self
															selector:@selector(updateAnimation:)
															userInfo:nil
															 repeats:YES];
		[self updateAnimation:nil];
	}
}

- (void)loadAnimImages {
	NSMutableArray* tmpImages = [NSMutableArray arrayWithCapacity:12];
	for(unsigned i=0; i<12; i++) {
		[tmpImages addObject:[NSImage imageNamed:[NSString stringWithFormat:@"ProgressWhite-%d", i]]];
	}
	
	// Make an immutable copy so this is reasonably fast
	animImages = [tmpImages copy];
}

- (void)updateAnimation:(NSTimer*)timer {
	if(![[self window] isVisible])
		return;
	
	if(!animImages)
		[self loadAnimImages];
	
	if(mouseInside)
		return;
	
	[self setImage:[animImages objectAtIndex:nextAnimImg]];
	[self setNeedsDisplay];
	nextAnimImg = (nextAnimImg+1) % [animImages count];
}

- (void)updateImageForMouseInside:(BOOL)inside {
	if(inside) {
		[self setImage:[NSImage imageNamed:NSImageNameStopProgressFreestandingTemplate]];
	} else {
		[self updateAnimation:nil];
	}

	mouseInside = inside;
}

- (void)mouseEntered:(NSEvent*)event {
	[self updateImageForMouseInside:YES];
}

- (void)mouseExited:(NSEvent*)event {
	[self updateImageForMouseInside:NO];
}

- (void)updateTrackingAreas {
	[super updateTrackingAreas];
	
	if(trackingArea)
		[self removeTrackingArea:trackingArea];
	trackingArea = [[NSTrackingArea alloc] initWithRect:[self visibleRect]
												options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect)
												  owner:self
											   userInfo:nil];
	[self addTrackingArea:trackingArea];
}

- (void)viewDidMoveToWindow {
	if([self window]) {
		NSPoint loc=[self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
		BOOL inside=([self hitTest:loc]==self);
		[self updateImageForMouseInside:inside];
	}
}

@end
