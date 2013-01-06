//  Copyright (c) 2005-2010 Decimus Software, Inc. All rights reserved.

#import "NoDragImageView.h"


@implementation NoDragImageView

- (void) awakeFromNib {
	[self unregisterDraggedTypes];
}

@end
