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
#import "KCDFeedbackViewController.h"

@interface KCDFeedbackViewController ()

@end

/*
 * The feedback demo is the simplest of all the tabs. The purpose is to demonstrate
 * the use of a disabled knob control with a custom image as a dial view. There are
 * two knob controls: one enabled, the other disabled. Whenever the enabled one
 * changes, the disabled one is simply set to the same position. The result is that
 * the bottom knob control does not respond to gestures but just reflects the
 * position of the top knob control, acting like a VU meter. This demo has no
 * configuration controls.
 */
@implementation KCDFeedbackViewController {
    IOSKnobControl* dialView;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.knobControl = [[IOSKnobControl alloc] initWithFrame:_knobHolder.bounds];
    self.knobControl.mode = IKCModeContinuous;
    self.knobControl.circular = NO;
    self.knobControl.min = -0.25*M_PI;
    self.knobControl.max = 0.25*M_PI;
    if ([self.knobControl respondsToSelector:@selector(setTintColor:)]) {
        // default anyway
        self.knobControl.tintColor = [UIColor blueColor];
    }
    UIColor* titleColor = [UIColor whiteColor];
    [self.knobControl setTitleColor:titleColor forState:UIControlStateNormal];
    [self.knobControl setTitleColor:titleColor forState:UIControlStateHighlighted];

    [self.knobControl addTarget:self action:@selector(knobTurned:) forControlEvents:UIControlEventValueChanged];
    [_knobHolder addSubview:self.knobControl];

    dialView = [[IOSKnobControl alloc] initWithFrame:_dialHolder.bounds imageNamed:@"needle"];
    dialView.mode = IKCModeContinuous;
    dialView.enabled = NO;
    dialView.clockwise = self.knobControl.clockwise;
    dialView.circular = self.knobControl.circular;
    dialView.min = self.knobControl.min;
    dialView.max = self.knobControl.max;
    [_dialHolder addSubview:dialView];

    // no need to arrange an action for UIControlEventValueChanged. this control will still generate those
    // events when the position is set programmatically, but who cares, since they're precisely
    // the same sequence of events as the first control.
}

#pragma mark - Knob control callback

- (void)knobTurned:(IOSKnobControl*)sender
{
    // Here's the meat: Set the dialView's position to the knobControl's position whenever
    // the latter changes.
    dialView.position = sender.position;
}

@end
