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

    // basic IOSKnobControl initialization (using default settings)
    knobControl = [[IOSKnobControl alloc] initWithFrame:self.knobControlView.bounds];

    // there is no default image atm, so must always set it (should add that to the constructor)
    knobControl.image = [UIImage imageNamed:@"hexagon"];

    // arrange to be notified whenever the knob turns
    [knobControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];

    // NOW hook it up to the demo
    [self.knobControlView addSubview:knobControl];

    [self updateKnobProperties];

    if (knobControl.mode == IKCMContinuous) {
        self.indexLabel.hidden = YES;
        self.indexLabelLabel.hidden = YES;
    }
}

- (void)updateKnobProperties
{
    knobControl.mode = IKCMDiscrete + self.modeControl.selectedSegmentIndex;
    knobControl.animation = IKCASlowReturn + self.animationControl.selectedSegmentIndex;
    knobControl.positions = self.positionsTextField.text.intValue;
    knobControl.circular = self.circularSwitch.on;
    knobControl.min = self.minTextField.text.floatValue;
    knobControl.max = self.maxTextField.text.floatValue;
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

    /*
     * Specification of animation and positions only applies to discrete mode.
     * Index is only displayed in discrete mode. Adjust accordingly, depending
     * on mode.
     */
    switch (mode) {
        case IKCMDiscrete:
            self.animationControl.enabled = YES;
            // for now, always use a hexagonal image, so positions is always 6
            // circular is always YES
            // self.positionsTextField.enabled = YES;
            self.indexLabelLabel.hidden = NO;
            self.indexLabel.hidden = NO;
            self.circularSwitch.on = YES;
            self.circularSwitch.enabled = NO;

            knobControl.image = [UIImage imageNamed:@"hexagon"];

            NSLog(@"Switched to discrete mode");
            break;
        case IKCMContinuous:
            self.animationControl.enabled = NO;
            self.positionsTextField.enabled = NO;
            self.indexLabelLabel.hidden = YES;
            self.indexLabel.hidden = YES;
            self.circularSwitch.enabled = YES;

            knobControl.image = [UIImage imageNamed:@"knob"];
            
            NSLog(@"Switched to continuous mode");
            break;
        case ICKMRotaryDial:
            self.animationControl.enabled = NO;
            self.positionsTextField.enabled = NO;
            self.indexLabelLabel.hidden = NO;
            self.indexLabel.hidden = NO;
            self.circularSwitch.enabled = NO;
            NSLog(@"Hello, Operator?");
            break;
    }

    [self updateKnobProperties];
}

- (void)animationChanged:(UISegmentedControl *)sender
{
    NSLog(@"Animation index changed to %d", sender.selectedSegmentIndex);
    [self updateKnobProperties];
}

- (void)circularChanged:(UISwitch *)sender
{
    NSLog(@"Circular is %@", (sender.on ? @"YES" : @"NO"));

    // with the hexagonal image for discrete mode, min and max don't make much sense
    self.minTextField.enabled = self.maxTextField.enabled = knobControl.mode == IKCMContinuous ? ! sender.on : NO;

    [self updateKnobProperties];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    [self updateKnobProperties];
    return YES;
}

@end
