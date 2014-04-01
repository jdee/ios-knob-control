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
#import "KCDDiscreteViewController.h"

@implementation KCDDiscreteViewController {
    IOSKnobControl* knobControl;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // basic IOSKnobControl initialization (using default settings) with an image from the bundle
    knobControl = [[IOSKnobControl alloc] initWithFrame:self.knobControlView.bounds /* imageNamed:@"hexagon-ccw" */];

    // arrange to be notified whenever the knob turns
    [knobControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];

    // Now hook it up to the demo
    [self.knobControlView addSubview:knobControl];

    [self updateKnobProperties];
}

- (void)updateKnobProperties
{
    knobControl.mode = self.modeControl.selectedSegmentIndex == 0 ? IKCMLinearReturn : IKCMWheelOfFortune;

    if (self.useHexagonImages) {
        knobControl.positions = 6;
        [knobControl setImage:self.hexagonImage forState:UIControlStateNormal];
    }
    else {
        knobControl.positions = 12;
        knobControl.titles = @[@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun", @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec"];
        [knobControl setImage:nil forState:UIControlStateNormal];
    }

    knobControl.circular = YES;
    knobControl.clockwise = self.clockwiseSwitch.on;
    knobControl.gesture = IKCGOneFingerRotation + self.gestureControl.selectedSegmentIndex;

    // tint and title colors
    if ([knobControl respondsToSelector:@selector(setTintColor:)]) {
        knobControl.tintColor = [UIColor greenColor];
    }

    UIColor* titleColor = [UIColor whiteColor];
    [knobControl setTitleColor:titleColor forState:UIControlStateNormal];
    [knobControl setTitleColor:titleColor forState:UIControlStateHighlighted];

    /*
     * The time scale control is logarithmic.
     */
    knobControl.timeScale = exp(self.timeScaleControl.value);

    knobControl.position = knobControl.position;
}

- (void)knobPositionChanged:(IOSKnobControl*)sender
{
    self.positionLabel.text = [NSString stringWithFormat:@"%.2f", knobControl.position];
    self.indexLabel.text = [NSString stringWithFormat:@"%ld", (long)knobControl.positionIndex];
}

- (UIImage*)hexagonImage
{
    return [UIImage imageNamed:self.clockwiseSwitch.on ? @"hexagon-cw" : @"hexagon-ccw"];
}

- (BOOL)useHexagonImages
{
    return _demoControl.selectedSegmentIndex > 0;
}

#pragma mark - Handlers for configuration controls

- (void)somethingChanged:(id)sender
{
    [self updateKnobProperties];
}

- (void)clockwiseChanged:(UISwitch *)sender
{
    if (self.useHexagonImages) {
        [knobControl setImage:self.hexagonImage forState:UIControlStateNormal];
    }
    [self updateKnobProperties];
}

@end