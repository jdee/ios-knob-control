//
//  IKCViewController.m
//  ios-knob-control
//
//  Created by Jimmy Dee on 1/30/14.
//  Copyright (c) 2014 Jimmy Dee. All rights reserved.
//

#import "IOSKnobControl.h"
#import "IKCViewController.h"

@interface IKCViewController () {
    IOSKnobControl* knobControl;
}

@end

@implementation IKCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    knobControl = [[IOSKnobControl alloc] initWithFrame:self.knobControlView.bounds];
    knobControl.image = [UIImage imageNamed:@"knob"];
    [self.knobControlView addSubview:knobControl];

    knobControl.mode = IKCMContinuous + self.modeControl.selectedSegmentIndex;
    knobControl.animation = IKCASlowReturn + self.animationControl.selectedSegmentIndex;
    knobControl.positions = self.positionsTextField.text.intValue;
    knobControl.circular = self.circularSwitch.on;
    knobControl.min = self.minTextField.text.floatValue;
    knobControl.max = self.maxTextField.text.floatValue;

    [knobControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];

    if (knobControl.mode == IKCMContinuous) {
        self.indexLabel.hidden = YES;
        self.indexLabelLabel.hidden = YES;
    }
}

- (void)knobPositionChanged:(IOSKnobControl*)sender
{
    self.positionLabel.text = [NSString stringWithFormat:@"%.2f", knobControl.position];

    if (knobControl.mode == IKCMDiscrete) {
        self.indexLabel.text = [NSString stringWithFormat:@"%d", knobControl.positionIndex];
    }
}

@end
