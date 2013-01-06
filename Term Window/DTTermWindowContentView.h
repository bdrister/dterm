//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

@class DTResultsView;

@interface DTTermWindowContentView : NSView {
	IBOutlet NSTextField* workingDirectoryTextField;
	IBOutlet NSTextField* commandTextField;
	IBOutlet NSButton* actionButton;
	
	IBOutlet DTResultsView* resultsView;
	
	BOOL alreadySizing;
}

@end
