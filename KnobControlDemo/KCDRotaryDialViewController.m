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

    UIColor* normalColor, *highlightedColor, *titleColor;
    normalColor = [UIColor colorWithRed:1.0 green:0.0 blue:1.0 alpha:0.7];
    highlightedColor = [UIColor colorWithRed:1.0 green:0.4 blue:1.0 alpha:0.7];
    titleColor = [UIColor colorWithRed:0.5 green:0.0 blue:0.5 alpha:1.0];

    [knobControl setFillColor:normalColor forState:UIControlStateNormal];
    [knobControl setFillColor:highlightedColor forState:UIControlStateHighlighted];
    [knobControl setTitleColor:titleColor forState:UIControlStateNormal];

    [knobControl addTarget:self action:@selector(dialed:) forControlEvents:UIControlEventValueChanged];
    [_knobHolder addSubview:knobControl];
}

- (void)dialed:(IOSKnobControl*)sender
{
}

@end
