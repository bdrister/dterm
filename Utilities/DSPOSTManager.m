//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DSPOSTManager.h"

static void POSTReadStreamCallBack(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    // Pass off to the object to handle.
    [((DSPOSTManager*)clientCallBackInfo) handleNetworkEvent:type];
}

@implementation DSPOSTManager

+ (id)postData:(NSDictionary*)data
		 toURL:(NSURL*)url
	  delegate:(id)delegate
	  selector:(SEL)selector
   contextInfo:(void*)contextInfo {
	return [[[DSPOSTManager alloc] initWithData:data
											URL:url
									   delegate:delegate
									   selector:selector
									contextInfo:contextInfo] autorelease];
}

- (id)initWithData:(NSDictionary*)_data
			   URL:(NSURL*)_url
		  delegate:(id)_delegate
		  selector:(SEL)_selector
	   contextInfo:(void*)_contextInfo {
	if((self = [super init])) {
		delegate = _delegate;
		selector = _selector;
		contextInfo = _contextInfo;
		
		results = [[NSMutableData alloc] init];
		
		// Build POST data
		NSMutableData* sendData = [NSMutableData data];
		for(NSString* key in _data) {
			NSString* escapedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			
			NSString* value = [_data objectForKey:key];
			NSMutableString* escapedValue = [[[value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] mutableCopy] autorelease];
			[escapedValue replaceOccurrencesOfString:@"+" withString:@"%2B" options:NSLiteralSearch range:NSMakeRange(0, [value length])];
			
			NSString* pairString = [NSString stringWithFormat:@"%@=%@", escapedKey, escapedValue];
			
			if([sendData length])
				[sendData appendBytes:"&" length:1];
			[sendData appendData:[pairString dataUsingEncoding:NSUTF8StringEncoding]];
		}
		
		// Create a new HTTP request
		CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), (CFURLRef)_url, kCFHTTPVersion1_1);
		if(!request) {
			NSLog(@"Couldn't create an HTTP request to submit purchasing data");
			[self release];
			return nil;
		}
		
		// Set headers and body
		CFHTTPMessageSetHeaderFieldValue(request,CFSTR("content-type"),CFSTR("application/x-www-form-urlencoded"));
		CFHTTPMessageSetBody(request, (CFDataRef)sendData);
		
		// Create the stream for the request
		stream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault,request);
		if(!stream) {
			NSLog(@"Couldn't create stream to submit purchasing data");
			CFRelease(request); request = nil;
			[self release];
			return nil;
		}
		
		// Set the stream client
		CFStreamClientContext context = { 0, self, NULL, NULL, NULL };
		if(!CFReadStreamSetClient(stream,
								  kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred,
								  POSTReadStreamCallBack,
								  &context)) {
			CFRelease(stream); stream = nil;
			CFRelease(request); request = nil;
			NSLog(@"Couldn't set the stream's client to submit purchasing data");
			[self release];
			return nil;
		}
		
		// Schedule the stream on the run loop
		CFReadStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
		
		// Start the HTTP connection
		if(!CFReadStreamOpen(stream)) {
			CFReadStreamSetClient(stream, 0, NULL, NULL);
			CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
			CFRelease(stream); stream = nil;
			CFRelease(request); request = nil;
			NSLog(@"Couldn't open the stream to submit purchasing data");
			[self release];
			return nil;
		}
		
		// Release the request.  The fetch should've retained it if it is performing the fetch.
		CFRelease(request); request = nil;
		
		// Ensure we stay around to hear our callbacks
		[self retain];
		[[NSGarbageCollector defaultCollector] disableCollectorForPointer:self];
	}
	
	return self;
}

- (void)handleNetworkEvent:(CFStreamEventType)type {
    // Dispatch the stream events.
    switch (type) {
        case kCFStreamEventHasBytesAvailable:
            [self handleBytesAvailable];
            break;
            
        case kCFStreamEventEndEncountered:
			[self notifyDelegateWithSuccess:YES error:NULL];
            break;
            
        case kCFStreamEventErrorOccurred:
            [self handleStreamError];
            break;
            
        default:
            break;
    }
}

- (void)handleBytesAvailable {
    UInt8 buffer[2048];
    CFIndex bytesRead = CFReadStreamRead(stream, buffer, sizeof(buffer));
    
    // Less than zero is an error
    if (bytesRead < 0)
        [self handleStreamError];
    
    // If bytes were read, append them
    else if (bytesRead)
		[results appendBytes:buffer length:bytesRead];
	
	// If zero bytes were read, wait for the EOF to come.
}

- (void)handleStreamError {
	// Grab a copy of the error
	CFErrorRef error = CFReadStreamCopyError(stream);
	
	// Notify the delegate
	[self notifyDelegateWithSuccess:NO error:error];
	
	// Release the error now that the delegate's seen it
	if(error)
		CFRelease(error);
}

- (void)notifyDelegateWithSuccess:(BOOL)wasSuccess
							error:(CFErrorRef)error {
	if(![delegate respondsToSelector:selector])
		return;
	
	NSInvocation* inv = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:selector]];
	[inv setTarget:delegate];
	[inv setSelector:selector];
	[inv setArgument:&self atIndex:2];
	[inv setArgument:&wasSuccess atIndex:3];
	[inv setArgument:&error atIndex:4];
	[inv setArgument:&results atIndex:5];
	
	[inv invoke];
	
	// Don't need the stream any more
    CFReadStreamSetClient(stream, 0, NULL, NULL);
    CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamClose(stream);
    CFRelease(stream); stream = nil;
	
	// Nor do we need results
	[results release]; results = nil;
	
	// And finally, we ourselves are now useless; allow ourselves to be released (balancing the retain/disableCollector in init)
	[self autorelease];
	[[NSGarbageCollector defaultCollector] enableCollectorForPointer:self];
}


@end
