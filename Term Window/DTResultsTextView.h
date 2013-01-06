//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.


@interface DTResultsTextView : NSTextView {
	BOOL validResultsStorage;
	NSTimer* sizeToFitTimer;
	
	BOOL disableAntialiasing;
}

@property BOOL disableAntialiasing;

- (NSSize)minSizeForContent;
- (CGFloat)desiredHeightChange;
- (void)dtSizeToFit;

@end
