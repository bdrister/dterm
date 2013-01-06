//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.

#import "DSNumberFormatterTransformer.h"


@implementation DSNumberFormatterTransformer

- (id)initWithNumberFormatter:(NSNumberFormatter*)_formatter {
	if((self = [super init])) {
		formatter = _formatter;
	}
	
	return self;
}

+ (Class)transformedValueClass {
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
	return NO;
}

- (id)transformedValue:(id)value {
	if(!value)
		return nil;
	
	return [formatter stringFromNumber:value];
}

@end
