//  DTTermWindowController.m
//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DTTermWindowController.h"

#import "DTAppController.h"
#import "DTCommandFieldEditor.h"
#import "DTTermWindowContentView.h"
#import "DTResultsView.h"
#import "DTResultsTextView.h"
#import "DTRunManager.h"
#import "DTShellUtilities.h"
//#import "Licensing.h"
#import "iTerm.h"
#import "iTerm2.h"
#import "Terminal.h"

static NSString* DTPreferencesContext = @"DTPreferencesContext";

@implementation DTTermWindowController

@synthesize workingDirectory, selectedURLs, command, runs, runsController;

- (id)init {
	if((self = [super initWithWindowNibName:@"TermWindow"])) {
		[self setShouldCascadeWindows:NO];
		
		self.command = @"";
		self.runs = [NSMutableArray array];
		
		NSUserDefaultsController *sdc = [NSUserDefaultsController sharedUserDefaultsController];
		[sdc addObserver:self forKeyPath:@"values.DTTextColor" options:0 context:DTPreferencesContext];
		[sdc addObserver:self forKeyPath:@"values.DTFontName" options:0 context:DTPreferencesContext];
		[sdc addObserver:self forKeyPath:@"values.DTFontSize" options:0 context:DTPreferencesContext];
	}
	
	return self;
}

- (void)windowDidLoad {
	NSPanel* panel = (NSPanel*)[self window];
	[panel setHidesOnDeactivate:NO];
	
	// On Lion, change the type of actionButton because they broke its display
	SInt32 minorOSVersion;
	if((noErr == Gestalt(gestaltSystemVersionMinor, &minorOSVersion)) &&
	   (minorOSVersion >= 7)) {
		[actionButton setBezelStyle:NSSmallSquareBezelStyle];
	}
	
	// Bind the results text storage up
	[resultsTextView bind:@"resultsStorage"
				 toObject:runsController
			  withKeyPath:@"selection.resultsStorage"
				  options:nil];
	
	// Swap in the results view for its placeholder
	[resultsView setFrame:[placeholderForResultsView frame]];
	[placeholderForResultsView removeFromSuperview];
	[[[self window] contentView] addSubview:resultsView];
	
	// Remove the excess action menu items if we're showing the dock icon
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	CFDictionaryRef processInfo = ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask);
	if(processInfo) {
		CFBooleanRef isLSUIElement = NULL;
		if(CFDictionaryGetValueIfPresent(processInfo, CFSTR("LSUIElement"), (const void **)&isLSUIElement) && isLSUIElement) {
			if(!CFBooleanGetValue(isLSUIElement)) {
				// It's not a UIElement, i.e. the dock icon is shown
				// Remove the menu items up to the last separator
				BOOL wasSeparator = NO;
				do {
					NSMenuItem* lastItem = [actionMenu itemAtIndex:([actionMenu numberOfItems]-1)];
					wasSeparator = [lastItem isSeparatorItem];
					[actionMenu removeItem:lastItem];
				} while(!wasSeparator && [actionMenu numberOfItems]);
			}
		}
		CFRelease(processInfo);
	}
}

- (id)windowWillReturnFieldEditor:(NSWindow*)window toObject:(id)anObject {
	if(window != [self window])
		return nil;
	if(anObject != commandField)
		return nil;
	
	if(!commandFieldEditor) {
		commandFieldEditor = [[DTCommandFieldEditor alloc] initWithController:self];
	}
	
	return commandFieldEditor;
}

- (void)setCommand:(NSString*)newCommand {
	command = newCommand;
	
	id firstResponder = [[self window] firstResponder];
	if([firstResponder isKindOfClass:[DTCommandFieldEditor class]]) {
		// We may be editing.  Make sure the field editor reflects the change too.
		NSTextStorage* textStorage = [firstResponder textStorage];
		[textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) 
								   withString:(newCommand ? newCommand : @"")];
	}
}


- (void)activateWithWorkingDirectory:(NSString*)wdPath
						   selection:(NSArray*)selection
						 windowFrame:(NSRect)frame {
	// Set the state variables
	self.workingDirectory = wdPath;
	self.selectedURLs = selection;
	
//	DTAppController* appController = [NSApp delegate];
//	if(!IS_REGISTERED && (appController.numCommandsExecuted >= 45)) {
//		long remainingCommands = (50 - appController.numCommandsExecuted);
//		if(remainingCommands == 1)
//			self.command = NSLocalizedString(@"1 command remaining in demo", NULL);
//		else
//			self.command = [NSString stringWithFormat:NSLocalizedString(@"%ld commands remaining in demo", NULL),
//							(long)remainingCommands];
//			
//	}
	
	// Hide window
	NSWindow* window = [self window];
	[window setAlphaValue:0.0];
	
	// Resize text view
	[resultsTextView minSize];
	// Select all of the command field
	[commandFieldEditor setSelectedRange:NSMakeRange(0, [[commandFieldEditor string] length])];
	[window makeFirstResponder:commandField];
	
	// If no parent window; use main screen
	if(NSEqualRects(frame, NSZeroRect)) {
		NSScreen* mainScreen = [NSScreen mainScreen];
		frame = [mainScreen visibleFrame];
	}
	
	// Set frame according to parent window location
	CGFloat desiredWidth = fmin(frame.size.width - 20.0, 640.0);
	NSRect newFrame = NSInsetRect(frame, (frame.size.width - desiredWidth) / 2.0, 0.0);
	newFrame.size.height = [window frame].size.height + [resultsTextView desiredHeightChange];
	newFrame.origin.y = frame.origin.y + frame.size.height - newFrame.size.height;
	[window setFrame:newFrame display:YES];
	
	[window makeKeyAndOrderFront:self];
	
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.1f];
	[[window animator] setAlphaValue:1.0];
	[NSAnimationContext endGrouping];
}

- (void)deactivate {
	NSInteger numRunsToKeep = [[NSUserDefaults standardUserDefaults] integerForKey:DTResultsToKeepKey];
	if(numRunsToKeep < 0)
		numRunsToKeep = 0;
	if(numRunsToKeep > 100)
		numRunsToKeep = 100;
	
	if([runs count] > numRunsToKeep) {
		// Delete non-running runs until we're below the threshold or are out of runs
		NSMutableArray* newRuns = [self.runs mutableCopy];
		
		unsigned i=0;
		while(([newRuns count] > numRunsToKeep) && (i < [newRuns count])) {
			DTRunManager* run = [newRuns objectAtIndex:i];
			if(run.task)
				i++;
			else
				[newRuns removeObjectAtIndex:i];								 
		}
		
		self.runs = newRuns;
	}
	
	
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.1f];
	[[[self window] animator] setAlphaValue:0.0];
	[NSAnimationContext endGrouping];
	
	[[self window] performSelector:@selector(orderOut:)
						withObject:self
						afterDelay:0.11f];
	
	[[NSApp delegate] saveStats];
}

- (void)windowDidResignKey:(NSNotification*)notification {
	if([notification object] != [self window])
		return;
	
	[self deactivate];
}

- (IBAction)insertSelection:(id)sender {
	NSMutableArray* paths = [NSMutableArray arrayWithCapacity:[selectedURLs count]];
	for(NSString* urlString in self.selectedURLs) {
		NSURL* url = [NSURL URLWithString:urlString];
		if([url isFileURL]) {
			NSString* newPath = [url path];
			if([newPath hasPrefix:workingDirectory]) {
				newPath = [newPath substringFromIndex:[workingDirectory length]];
				if([newPath hasPrefix:@"/"])
					newPath = [newPath substringFromIndex:1];
			}
			[paths addObject:[escapedPath(newPath) mutableCopy]];
		}
	}
	
	[commandFieldEditor insertFiles:paths];
}
- (IBAction)insertSelectionFullPaths:(id)sender {
	NSMutableArray* paths = [NSMutableArray arrayWithCapacity:[selectedURLs count]];
	for(NSString* urlString in self.selectedURLs) {
		NSURL* url = [NSURL URLWithString:urlString];
		if([url isFileURL]) {
			NSString* newPath = [url path];
			[paths addObject:[escapedPath(newPath) mutableCopy]];
		}
	}
	
	[commandFieldEditor insertFiles:paths];
}
- (IBAction)pullCommandFromResults:(id)sender {
	id selection = [runsController selection];
	NSString* resultsCommand = [selection valueForKey:@"command"];
	if(resultsCommand) {
		// At this point, self.command is still the last executed command (?!), so we have to use
		// the length of [commandFieldEditor string] to reflect anything the user's typed since then
		// https://decimus.fogbugz.com/default.asp?11185
		[commandFieldEditor setSelectedRange:NSMakeRange(0, [[commandFieldEditor string] length])];
		[commandFieldEditor insertText:resultsCommand];
	}
}
- (IBAction)executeCommand:(id)sender {
	// Commit editing first
	if(![[self window] makeFirstResponder:[self window]])
		return;
	
	if(!self.command || ![self.command length])
		return;
	
	DTAppController* appController = [NSApp delegate];
	
//	if(IS_REGISTERED || (appController.numCommandsExecuted < 50)) {
		appController.numCommandsExecuted++;
		DTRunManager* runManager = [[DTRunManager alloc] initWithWD:self.workingDirectory
														  selection:self.selectedURLs
															command:self.command
														demoExpired:NO];
		[runsController addObject:runManager];
//	} else {
//		DTRunManager* runManager = [[DTRunManager alloc] initWithWD:NSHomeDirectory()
//														  selection:[NSArray array]
//															command:self.command
//														demoExpired:YES];
//		[runsController addObject:runManager];
//	}
}

- (IBAction)executeCommandInTerminal:(id)sender {
	// Commit editing first
	if(![[self window] makeFirstResponder:[self window]])
		return;
	
	DTAppController* appController = [NSApp delegate];
	NSString* cdCommandString = [NSString stringWithFormat:@"cd %@", escapedPath(self.workingDirectory)];
	
//	if(IS_REGISTERED || (appController.numCommandsExecuted <= 50)) {
	appController.numCommandsExecuted++;
	
	id iTerm = [SBApplication applicationWithBundleIdentifier:@"net.sourceforge.iTerm"];
	if(!iTerm)
		iTerm = [SBApplication applicationWithBundleIdentifier:@"com.googlecode.iterm2"];
	if(iTerm) {
		id /*iTermTerminal*/ terminal = nil;
		id /*iTermSession*/ session = nil;
		
		if([iTerm isRunning]) {
			// set terminal to (make new terminal at the end of terminals)
			terminal = [[[iTerm classForScriptingClass:@"terminal"] alloc] init];
			[[iTerm terminals] addObject:terminal];
			
			// set session to (make new session at the end of sessions)
			session = [[[iTerm classForScriptingClass:@"session"] alloc] init];
			[[terminal sessions] addObject:session];
		} else {
			// It wasn't running yet, so just use the "current" terminal/session so we don't open more than one
			terminal = [iTerm currentTerminal];
			session = [terminal currentSession];
		}
		
		// set shell to system attribute "SHELL"
		// exec command shell
		[session execCommand:[DTRunManager shellPath]];
		
		// write text "cd ~/whatever"
		[session writeContentsOfFile:nil text:cdCommandString];
		
		// write text "thecommand"
		[session writeContentsOfFile:nil text:self.command];
		
		[iTerm activate];
	} else {
		TerminalApplication* terminal = [SBApplication applicationWithBundleIdentifier:@"com.apple.Terminal"];
		BOOL terminalAlreadyRunning = [terminal isRunning];
		
		TerminalWindow* frontWindow = [[terminal windows] objectAtIndex:0];
		if(![frontWindow exists])
			frontWindow = nil;
		else
			frontWindow = [frontWindow get];
		
		TerminalTab* tab = nil;
		if(frontWindow) {
			if(!terminalAlreadyRunning) {
				tab = [[frontWindow tabs] objectAtIndex:0];
			} else if(/*terminalUsesTabs*/false) {
				tab = [[[terminal classForScriptingClass:@"tab"] alloc] init];
				[[frontWindow tabs] addObject:tab];
			}
		}
		
		tab = [terminal doScript:cdCommandString in:tab];
		[terminal doScript:self.command in:tab];
		
		[terminal activate];
	}
	
//	} else {
//		DTRunManager* runManager = [[DTRunManager alloc] initWithWD:NSHomeDirectory()
//														  selection:[NSArray array]
//															command:self.command
//														demoExpired:YES];
//		[runsController addObject:runManager];
//	}
}


- (void)cancelOperation:(id)sender {
	[self deactivate];
}

- (IBAction)copyResultsToClipboard:(id)sender {
//	[[NSSound soundNamed:@"Blow"] play];
	//	NSLog(@"Asked to copy results to clipboard");
	
	id selection = [runsController selection];
	NSTextStorage* resultsStorage = [selection valueForKey:@"resultsStorage"];
	if(!resultsStorage)
		return;
	
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[pb setString:[resultsStorage string] forType:NSStringPboardType];
	
	[self deactivate];
}

- (IBAction)cancelCurrentCommand:(id)sender {
	NSArray* selection = [runsController selectedObjects];
	[selection makeObjectsPerformSelector:@selector(cancel:) withObject:sender];
}

- (void)requestWindowHeightChange:(CGFloat)dHeight {
	NSWindow* window = [self window];
	
	// Calculate new frame, ignoring window constraint
	NSRect windowFrame = [window frame];
	windowFrame.size.height += dHeight;
	windowFrame.origin.y -= dHeight;
	
	// Adjust bottom edge so it's on the screen
	NSScreen* screen = [window screen];
	NSRect screenRect = [screen visibleFrame];
	dHeight = windowFrame.origin.y - screenRect.origin.y;
	if(dHeight < 0.0) {
		windowFrame.size.height += dHeight;
		windowFrame.origin.y -= dHeight;
	}
	
	[window setFrame:windowFrame
			 display:YES
			 animate:YES];
}

- (NSArray*)completionsForPartialWord:(NSString*)partialWord
							isCommand:(BOOL)isCommand
				  indexOfSelectedItem:(NSInteger*)index {
	BOOL allowFiles = (!isCommand || [partialWord hasPrefix:@"/"] || [partialWord hasPrefix:@"./"] || [partialWord hasPrefix:@"../"]);
	
	NSTask* task = [[NSTask alloc] init];
	[task setCurrentDirectoryPath:self.workingDirectory];
	[task setLaunchPath:@"/bin/bash"];
	[task setArguments:[DTRunManager argumentsToRunCommand:[NSString stringWithFormat:@"compgen -%@%@%@ %@",
															([[[DTRunManager shellPath] lastPathComponent] isEqualToString:@"bash"] ? @"a" : @""),
															(isCommand ? @"bc" : @""),
															(allowFiles ? @"df" : @""),
															partialWord]]];
	
	// Attach pipe to task's standard output
	NSPipe* newPipe = [NSPipe pipe];
	NSFileHandle* stdOut = [newPipe fileHandleForReading];
	[task setStandardOutput:newPipe];
	
	// Setting the accessibility flag gives us a sticky egid of 'accessibility', which seems to interfere with shells using .bashrc and whatnot.
	// We temporarily set our gid back before launching to work around this problem.
	// Case 8042: http://fogbugz.decimus.net/default.php?8042
	gid_t savedEGID = getegid();
	setegid(getgid());
	[task launch];
	setegid(savedEGID);
	
	NSData* resultsData = [stdOut readDataToEndOfFile];
	NSString* results = [[NSString alloc] initWithData:resultsData encoding:NSUTF8StringEncoding];
	
	NSMutableSet* completionsSet = [NSMutableSet setWithArray:[results componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
	[completionsSet removeObject:@""];
	
	NSMutableArray* completions = [NSMutableArray arrayWithCapacity:[completionsSet count]];
	NSFileManager* fileManager = [NSFileManager defaultManager];
	for(NSString* completion in completionsSet) {
		NSString* actualPath = ([completion hasPrefix:@"/"] ? completion : [workingDirectory stringByAppendingPathComponent:completion]);
		BOOL isDirectory = NO;
		if([fileManager fileExistsAtPath:actualPath isDirectory:&isDirectory] && isDirectory)
			completion = [completion stringByAppendingString:@"/"];
		
		[completions addObject:completion];
	}
	
	if(![completions count])
		return nil;
	
	[completions sortUsingDescriptors:[NSArray arrayWithObjects:
									   [[NSSortDescriptor alloc] initWithKey:@"length" ascending:YES],
									   [[NSSortDescriptor alloc] initWithKey:@"lowercaseString" ascending:YES],
									   nil]];
	
	return completions;
}

#pragma mark font/color support

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context {
	if(context != DTPreferencesContext){
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if([keyPath isEqualToString:@"values.DTFontName"] || [keyPath isEqualToString:@"values.DTFontSize"]) {
		NSFont* newFont = [NSFont fontWithName:[defaults objectForKey:DTFontNameKey]
										  size:[defaults doubleForKey:DTFontSizeKey]];
		for(DTRunManager* run in runs)
			[run setDisplayFont:newFont];
	} else if([keyPath isEqualToString:@"values.DTTextColor"]) {
		NSColor* newColor = [NSKeyedUnarchiver unarchiveObjectWithData:[defaults objectForKey:DTTextColorKey]];
		for(DTRunManager* run in runs)
			[run setDisplayColor:newColor];
	}
	
	[[[self window] contentView] setNeedsDisplay:YES];
}

- (CGFloat)resultsCommandFontSize {
	return 10.0;
}

@end
