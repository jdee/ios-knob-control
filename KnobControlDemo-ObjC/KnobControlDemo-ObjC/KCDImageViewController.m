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
#import "KCDImageChooser.h"
#import "KCDImageViewController.h"

/*
 * This View Controller is presented modally by the continuous and rotary dial views when
 * the Images button is tapped in either one, to allow the user to see yet another knob
 * control and select a set of images to use for the control(s) in that demo. The two demos
 * have different image requirements, so the list in each case is different and specified
 * by setting the titles property of the destinationViewController in the other view
 * controller's prepareForSegue(,sender:) method. The titles are used to construct a discrete
 * knob in ICKModeLinearReturn mode. The user selects an image set by rotating that name to the
 * top, where it is mest legible. Then she taps the Choose button, the model view controller
 * disappears, and the main view controller's imageChosen() method is called.
 */
@implementation KCDImageViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.knobControl = [[IOSKnobControl alloc] initWithFrame:_knobHolder.bounds];
    self.knobControl.mode = IKCModeLinearReturn;
    self.knobControl.positions = _titles.count;
    self.knobControl.titles = _titles;
    self.knobControl.timeScale = 0.5;
    self.knobControl.circular = NO;
    self.knobControl.min = -M_PI/2.0;
    self.knobControl.max = M_PI/2.0;

    // self.knobControl.fontName = @"CourierNewPS-BoldMT";
    // self.knobControl.fontName = @"Verdana-Bold";
    // self.knobControl.fontName = @"Georgia-Bold";
    // self.knobControl.fontName = @"TimesNewRomanPS-BoldMT";
    // self.knobControl.fontName = @"AvenirNext-Bold";
    self.knobControl.fontName = @"TrebuchetMS-Bold";

    // tint and title colors
    UIColor* titleColor = [UIColor whiteColor];
    if ([self.knobControl respondsToSelector:@selector(setTintColor:)]) {
        self.knobControl.tintColor = [UIColor yellowColor];
        titleColor = [UIColor blackColor];
    }

    [self.knobControl setTitleColor:titleColor forState:UIControlStateNormal];
    [self.knobControl setTitleColor:titleColor forState:UIControlStateHighlighted];

    [_knobHolder addSubview:self.knobControl];

    // note that we don't care here when the knob is rotated; we don't do anything in response in the app code.
    // only in done() when the user taps Choose do we consult the knob's positionIndex to find the chosen title
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.knobControl.positionIndex = _imageTitle ? [_titles indexOfObject:_imageTitle] : [_titles indexOfObject:@"(none)"];
}

#pragma Action for storyboard outlet

- (void)done:(id)sender
{
    NSString* title = [_titles objectAtIndex:self.knobControl.positionIndex];

    if ([title isEqualToString:@"(none)"]) {
        title = nil;
    }
    [_delegate imageChosen:title];

    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
