//
//  KCDFeedbackViewController.m
//  KnobControlDemo
//
//  Created by Jimmy Dee on 4/1/14.
//  Copyright (c) 2014 Your Organization. All rights reserved.
//

#import "IOSKnobControl.h"
#import "KCDFeedbackViewController.h"

@interface KCDFeedbackViewController ()

@end

@implementation KCDFeedbackViewController {
    IOSKnobControl* knobControl;
    IOSKnobControl* dialControl;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    knobControl = [[IOSKnobControl alloc] initWithFrame:_knobHolder.bounds];
    knobControl.mode = IKCMContinuous;
    knobControl.circular = NO;
    knobControl.min = -0.25*M_PI;
    knobControl.max = 0.25*M_PI;
    if ([knobControl respondsToSelector:@selector(setTintColor:)]) {
        // default anyway
        knobControl.tintColor = [UIColor blueColor];
    }
    UIColor* titleColor = [UIColor whiteColor];
    [knobControl setTitleColor:titleColor forState:UIControlStateNormal];
    [knobControl setTitleColor:titleColor forState:UIControlStateHighlighted];

    [knobControl addTarget:self action:@selector(knobTurned:) forControlEvents:UIControlEventValueChanged];
    [_knobHolder addSubview:knobControl];

    dialControl = [[IOSKnobControl alloc] initWithFrame:_dialHolder.bounds imageNamed:@"needle"];
    dialControl.mode = IKCMContinuous;
    dialControl.enabled = NO;
    dialControl.clockwise = knobControl.clockwise;
    dialControl.circular = knobControl.circular;
    dialControl.min = knobControl.min;
    dialControl.max = knobControl.max;
    [_dialHolder addSubview:dialControl];
}

- (void)knobTurned:(IOSKnobControl*)sender
{
    dialControl.position = sender.position;
}

@end
