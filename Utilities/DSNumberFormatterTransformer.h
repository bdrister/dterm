//  Copyright (c) 2007-2010 Decimus Software, Inc. All rights reserved.


@interface DSNumberFormatterTransformer : NSValueTransformer {
	NSNumberFormatter* formatter;
}

- (id)initWithNumberFormatter:(NSNumberFormatter*)_formatter;

@end
