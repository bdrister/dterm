//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DSDecimalToIntegerTransformer.h"


@implementation DSDecimalToIntegerTransformer

+ (Class)transformedValueClass {
	return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation {
	return YES;
}

- (id)transformedValue:(id)value {
	// NSDecimalNumber already is an NSNumber, so nothing needed
	return value;
}

- (id)reverseTransformedValue:(id)value {
	if(![value respondsToSelector:@selector(decimalValue)]) {
		[NSException raise:NSInternalInconsistencyException
					format:@"Value (%@) does not respond to -decimalValue (EB71BC11-9C3E-495C-AA70-BCF8B3F83B7F)", value];
	}
	
	return [[NSDecimalNumber alloc] initWithDecimal:[value decimalValue]];
}

@end
