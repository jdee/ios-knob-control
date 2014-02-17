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
    IOSKnobControl* minControl;
    IOSKnobControl* maxControl;
}

@end

@implementation IKCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // basic IOSKnobControl initialization (using default settings) with an image from the bundle
    knobControl = [[IOSKnobControl alloc] initWithFrame:self.knobControlView.bounds imageNamed:@"hexagon"];

    // arrange to be notified whenever the knob turns
    [knobControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];

    // Now hook it up to the demo
    [self.knobControlView addSubview:knobControl];

    [self setupMinAndMaxControls];

    [self updateKnobProperties];

    if (knobControl.mode == IKCMContinuous) {
        self.indexLabel.hidden = YES;
        self.indexLabelLabel.hidden = YES;
    }
}

- (void)updateKnobProperties
{
    knobControl.mode = IKCMLinearReturn + self.modeControl.selectedSegmentIndex;
    knobControl.positions = self.positionsTextField.text.intValue;
    knobControl.circular = self.circularSwitch.on;
    knobControl.min = minControl.position;
    knobControl.max = maxControl.position;
    knobControl.clockwise = self.clockwiseSwitch.on;

    /*
     * The control ranges from -1 to 1, starting at 0. This avoids compressing the
     * scale in the range below 0.
     */
    knobControl.timeScale = exp(self.timeScaleControl.value);

    minControl.clockwise = maxControl.clockwise = knobControl.clockwise;

    minControl.position = minControl.position;
    maxControl.position = maxControl.position;

    knobControl.position = knobControl.position;

    // with the current hexagonal image for discrete mode, min and max don't make much sense
    minControl.enabled = maxControl.enabled = knobControl.mode == IKCMContinuous ? self.circularSwitch.on == NO : NO;
}

- (void)knobPositionChanged:(IOSKnobControl*)sender
{
    if (sender == knobControl) {
        self.positionLabel.text = [NSString stringWithFormat:@"%.2f", knobControl.position];

        if (knobControl.mode != IKCMContinuous) {
            self.indexLabel.text = [NSString stringWithFormat:@"%d", knobControl.positionIndex];
        }
    }
    else if (sender == minControl) {
        self.minLabel.text = [NSString stringWithFormat:@"%.2f", minControl.position];
        knobControl.min = minControl.position;
    }
    else if (sender == maxControl) {
        self.maxLabel.text = [NSString stringWithFormat:@"%.2f", maxControl.position];
        knobControl.max = maxControl.position;
    }
}

- (void)setupMinAndMaxControls
{
    // Both controls use the same image in continuous mode with circular set to NO. The clockwise
    // property is set to the same value as the main knob (the value of self.clockwiseSwitch.on).
    // That happens in updateKnobProperties.
    minControl = [[IOSKnobControl alloc] initWithFrame:self.minControlView.bounds];
    maxControl = [[IOSKnobControl alloc] initWithFrame:self.maxControlView.bounds];

    [minControl setImage:[UIImage imageNamed:@"knob-85x85"] forState:UIControlStateNormal];
    [minControl setImage:[UIImage imageNamed:@"knob-disabled-85x85"] forState:UIControlStateDisabled];
    [minControl setImage:[UIImage imageNamed:@"knob-highlighted-85x85"] forState:UIControlStateHighlighted];
    [maxControl setImage:[UIImage imageNamed:@"knob-85x85"] forState:UIControlStateNormal];
    [maxControl setImage:[UIImage imageNamed:@"knob-disabled-85x85"] forState:UIControlStateDisabled];
    [maxControl setImage:[UIImage imageNamed:@"knob-highlighted-85x85"] forState:UIControlStateHighlighted];

    minControl.mode = maxControl.mode = IKCMContinuous;
    minControl.circular = maxControl.circular = NO;

    // reuse the same knobPositionChanged: method
    [minControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];
    [maxControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];

    // the min. control ranges from -M_PI to 0 and starts at -0.5*M_PI
    minControl.min = -M_PI;
    minControl.max = 0.0;
    minControl.position = -0.5*M_PI;

    // the max. control ranges from 0 to M_PI and starts at 0.5*M_PI
    maxControl.min = 0.0;
    maxControl.max = M_PI;
    maxControl.position = 0.5*M_PI;

    // add each to its placeholder
    [self.minControlView addSubview:minControl];
    [self.maxControlView addSubview:maxControl];
}

#pragma mark - Handlers for configuration controls

- (void)modeChanged:(UISegmentedControl *)sender
{
    NSLog(@"Mode index changed to %ld", (long)sender.selectedSegmentIndex);
    IKCMode mode = IKCMLinearReturn + (int)sender.selectedSegmentIndex;

    /*
     * Specification of animation and positions only applies to discrete mode.
     * Index is only displayed in discrete mode. Adjust accordingly, depending
     * on mode.
     */
    switch (mode) {
        case IKCMLinearReturn:
        case IKCMWheelOfFortune:
            // for now, always use a hexagonal image, so positions is always 6
            // circular is always YES
            // self.positionsTextField.enabled = YES;
            self.positionsTextField.enabled = NO;
            self.indexLabelLabel.hidden = NO;
            self.indexLabel.hidden = NO;
            self.circularSwitch.on = YES;
            self.circularSwitch.enabled = NO;
            self.clockwiseSwitch.on = YES;
            self.clockwiseSwitch.enabled = NO;

            [knobControl setImage:[UIImage imageNamed:@"hexagon"] forState:UIControlStateNormal];
            [knobControl setImage:nil forState:UIControlStateHighlighted];

            NSLog(@"Switched to discrete mode");
            break;
        case IKCMContinuous:
            self.positionsTextField.enabled = NO;
            self.indexLabelLabel.hidden = YES;
            self.indexLabel.hidden = YES;
            self.circularSwitch.enabled = YES;
            self.clockwiseSwitch.enabled = YES;

            [knobControl setImage:[UIImage imageNamed:@"knob"] forState:UIControlStateNormal];
            [knobControl setImage:[UIImage imageNamed:@"knob-highlighted"] forState:UIControlStateHighlighted];
            [knobControl setImage:[UIImage imageNamed:@"knob-disabled"] forState:UIControlStateDisabled];
            // [knobControl setImage:[UIImage imageNamed:@"knob"] forState:UIControlStateSelected];

            NSLog(@"Switched to continuous mode");
            break;
        case IKCMRotaryDial:
            self.positionsTextField.enabled = NO;
            self.indexLabelLabel.hidden = NO;
            self.indexLabel.hidden = NO;
            self.circularSwitch.enabled = NO;
            self.clockwiseSwitch.enabled = NO;
            NSLog(@"Hello, Operator?");
            break;
    }

    [self updateKnobProperties];
}

- (void)circularChanged:(UISwitch *)sender
{
    NSLog(@"Circular is %@", (sender.on ? @"YES" : @"NO"));
    [self updateKnobProperties];
}

- (void)clockwiseChanged:(UISwitch *)sender
{
    [self updateKnobProperties];
}

- (void)scaleChanged:(UISlider *)sender
{
    [self updateKnobProperties];
}

@end
