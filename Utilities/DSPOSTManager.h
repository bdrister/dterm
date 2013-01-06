//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.


@interface DSPOSTManager : NSObject {
	id delegate;
	SEL selector;
	void* contextInfo;
	
	CFReadStreamRef stream;
	NSMutableData* results;
}

// Delegate selectors must match the signature of:
//- (void)postManager:(DSPostManager*)pm
//completedWithSuccess:(BOOL)success
//			  error:(CFErrorRef)error
//			 result:(NSData*)result;

+ (id)postData:(NSDictionary*)data
		 toURL:(NSURL*)url
	  delegate:(id)delegate
	  selector:(SEL)selector
   contextInfo:(void*)contextInfo;

- (id)initWithData:(NSDictionary*)_data
			   URL:(NSURL*)_url
		  delegate:(id)_delegate
		  selector:(SEL)_selector
	   contextInfo:(void*)_contextInfo;

- (void)handleNetworkEvent:(CFStreamEventType)type;
- (void)handleBytesAvailable;
- (void)handleStreamError;
- (void)notifyDelegateWithSuccess:(BOOL)wasSuccess
							error:(CFErrorRef)error;

@end