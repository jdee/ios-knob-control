//
//  KCDRotaryDialViewController.m
//  KnobControlDemo
//
//  Created by Jimmy Dee on 5/25/14.
//  Copyright (c) 2014 Your Organization. All rights reserved.
//

#import "IOSKnobControl.h"
#import "KCDRotaryDialViewController.h"

@implementation KCDRotaryDialViewController {
    IOSKnobControl* knobControl;
}

- (void)viewDidLoad
{
    knobControl = [[IOSKnobControl alloc] initWithFrame:_knobHolder.bounds];
    knobControl.mode = IKCMRotaryDial;
    [knobControl addTarget:self action:@selector(dialed:) forControlEvents:UIControlEventValueChanged];
    [_knobHolder addSubview:knobControl];
}

- (void)dialed:(IOSKnobControl*)sender
{
}

@end
