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

    knobControl.mode = IKCMDiscrete + self.modeControl.selectedSegmentIndex;
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

    if (knobControl.mode != IKCMContinuous) {
        self.indexLabel.text = [NSString stringWithFormat:@"%d", knobControl.positionIndex];
    }
}

#pragma mark - Handlers for configuration controls

- (void)modeChanged:(UISegmentedControl *)sender
{
    NSLog(@"Mode index changed to %d", sender.selectedSegmentIndex);
    enum IKCMode mode = IKCMDiscrete + sender.selectedSegmentIndex;
    switch (mode) {
        case IKCMContinuous:
            self.animationControl.enabled = NO;
            self.positionsTextField.enabled = NO;
            self.indexLabelLabel.hidden = YES;
            self.indexLabel.hidden = YES;
            NSLog(@"Switched to continuous mode");
            break;
        case IKCMDiscrete:
            self.animationControl.enabled = YES;
            self.positionsTextField.enabled = YES;
            self.indexLabelLabel.hidden = NO;
            self.indexLabel.hidden = NO;
            NSLog(@"Switched to discrete mode");
            break;
        case ICKMRotaryDial:
            self.animationControl.enabled = NO;
            self.positionsTextField.enabled = NO;
            self.indexLabelLabel.hidden = NO;
            self.indexLabel.hidden = NO;
            NSLog(@"Hello, Operator?");
            break;
    }

    knobControl.mode = mode;
}

- (void)animationChanged:(UISegmentedControl *)sender
{
    NSLog(@"Animation index changed to %d", sender.selectedSegmentIndex);
    enum IKCAnimation animation = IKCASlowReturn + sender.selectedSegmentIndex;
    knobControl.animation = animation;
}

- (void)circularChanged:(UISwitch *)sender
{
    NSLog(@"Circular is %@", (sender.on ? @"YES" : @"NO"));
    self.minTextField.enabled = self.maxTextField.enabled = ! sender.on;
    knobControl.circular = sender.on;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];

    if (textField == self.positionsTextField) {
        knobControl.positions = textField.text.intValue;
    }
    else if (textField == self.minTextField) {
        knobControl.min = textField.text.floatValue;
    }
    else {
        knobControl.max = textField.text.floatValue;
    }

    return YES;
}

@end
