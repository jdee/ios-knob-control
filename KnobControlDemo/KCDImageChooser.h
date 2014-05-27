//
//  KCDImageChooser.h
//  KnobControlDemo
//
//  Created by Jimmy Dee on 5/27/14.
//  Copyright (c) 2014 Your Organization. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol KCDImageChooser <NSObject>

- (void)imageChosen:(NSString*)imageTitle;

@end
