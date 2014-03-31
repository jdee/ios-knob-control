/*
 Copyright (c) 2013-14, Jimmy Dee
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "IOSKnobControl.h"
#import "KCDAppDelegate.h"
#import "KCDContinuousViewController.h"

@implementation KCDContinuousViewController {
    IOSKnobControl* knobControl;
    IOSKnobControl* minControl;
    IOSKnobControl* maxControl;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // basic continuous knob configuration
    knobControl = [[IOSKnobControl alloc] initWithFrame:self.knobControlView.bounds];
    knobControl.mode = IKCMContinuous;

    // arrange to be notified whenever the knob turns
    [knobControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];

    // Now hook it up to the demo
    [self.knobControlView addSubview:knobControl];

    [self setupMinAndMaxControls];

    [self updateKnobProperties];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateKnobImages];
    [self updateKnobProperties];

    NSLog(@"Min. knob position %f, max. knob position %f", minControl.position, maxControl.position);
}

- (void)updateKnobImages
{
    KCDAppDelegate* appDelegate = (KCDAppDelegate*)[UIApplication sharedApplication].delegate;

    if (appDelegate.imageTitle) {
        [knobControl setImage:[UIImage imageNamed:appDelegate.imageTitle] forState:UIControlStateNormal];
        [knobControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-highlighted", appDelegate.imageTitle]] forState:UIControlStateHighlighted];
        [knobControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-disabled", appDelegate.imageTitle]] forState:UIControlStateDisabled];

        // Use the same three images for each knob.
        [minControl setImage:[UIImage imageNamed:appDelegate.imageTitle] forState:UIControlStateNormal];
        [minControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-highlighted", appDelegate.imageTitle]] forState:UIControlStateHighlighted];
        [minControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-disabled", appDelegate.imageTitle]] forState:UIControlStateDisabled];

        [maxControl setImage:[UIImage imageNamed:appDelegate.imageTitle] forState:UIControlStateNormal];
        [maxControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-highlighted", appDelegate.imageTitle]] forState:UIControlStateHighlighted];
        [maxControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-disabled", appDelegate.imageTitle]] forState:UIControlStateDisabled];
    }
    else {
        [knobControl setImage:nil forState:UIControlStateNormal];
        [knobControl setImage:nil forState:UIControlStateHighlighted];
        [knobControl setImage:nil forState:UIControlStateDisabled];

        [minControl setImage:nil forState:UIControlStateNormal];
        [minControl setImage:nil forState:UIControlStateHighlighted];
        [minControl setImage:nil forState:UIControlStateDisabled];

        [maxControl setImage:nil forState:UIControlStateNormal];
        [maxControl setImage:nil forState:UIControlStateHighlighted];
        [maxControl setImage:nil forState:UIControlStateDisabled];
    }
}

- (void)updateKnobProperties
{
    knobControl.circular = self.circularSwitch.on;
    knobControl.min = minControl.position;
    knobControl.max = maxControl.position;
    knobControl.clockwise = self.clockwiseSwitch.on;

    // configure the tint color
    minControl.tintColor = maxControl.tintColor = knobControl.tintColor = [UIColor greenColor];

    minControl.gesture = maxControl.gesture = knobControl.gesture = IKCGOneFingerRotation + self.gestureControl.selectedSegmentIndex;

    minControl.clockwise = maxControl.clockwise = knobControl.clockwise;

    minControl.position = minControl.position;
    maxControl.position = maxControl.position;

    knobControl.position = knobControl.position;

    minControl.enabled = maxControl.enabled = self.circularSwitch.on == NO;
}

- (void)knobPositionChanged:(IOSKnobControl*)sender
{
    if (sender == knobControl) {
        self.positionLabel.text = [NSString stringWithFormat:@"%.2f", knobControl.position];
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

    minControl.mode = maxControl.mode = IKCMContinuous;
    minControl.circular = maxControl.circular = NO;

    // reuse the same knobPositionChanged: method
    [minControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];
    [maxControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];

    // the min. control ranges from -M_PI to 0 and starts at -0.5*M_PI
    minControl.min = -M_PI + 1e-7;
    minControl.max = 0.0;
    minControl.position = -M_PI_2;

    // the max. control ranges from 0 to M_PI and starts at 0.5*M_PI
    maxControl.min = 0.0;
    maxControl.max = M_PI - 1e-7;
    maxControl.position = M_PI_2;

    // add each to its placeholder
    [self.minControlView addSubview:minControl];
    [self.maxControlView addSubview:maxControl];
}

#pragma mark - Handler for configuration controls

- (void)somethingChanged:(id)sender
{
    [self updateKnobProperties];
}

@end
