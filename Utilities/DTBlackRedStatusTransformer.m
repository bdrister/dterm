//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DTBlackRedStatusTransformer.h"


@implementation DTBlackRedStatusTransformer

+ (Class)transformedValueClass {
	return [NSColor class];
}

+ (BOOL)allowsReverseTransformation {
	return NO;
}

- (id)transformedValue:(id)value {
	if(!value)
		return nil;
	
	if(![value respondsToSelector:@selector(boolValue)]) {
		[NSException raise:NSInternalInconsistencyException
					format:@"Value (%@) does not respond to -boolValue (743B73A8-32AA-4824-87B6-9AA5FD6CBB53)", value];
	}
	
	if([value boolValue])
		return [NSColor blackColor];
	else
		return [NSColor redColor];
}

@end
