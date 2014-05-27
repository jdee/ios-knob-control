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
#import "KCDImageViewController.h"
#import "KCDRotaryDialViewController.h"

@implementation KCDRotaryDialViewController {
    IOSKnobControl* knobControl;
    NSString* numberDialed, *imageTitle;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    imageTitle = @"(none)";

    knobControl = [[IOSKnobControl alloc] initWithFrame:_knobHolder.bounds];
    knobControl.mode = IKCMRotaryDial;
    knobControl.gesture = IKCGOneFingerRotation;

    UIColor* normalColor, *highlightedColor, *titleColor;
    normalColor = [UIColor colorWithRed:1.0 green:0.0 blue:1.0 alpha:0.7];
    highlightedColor = [UIColor colorWithRed:1.0 green:0.4 blue:1.0 alpha:0.7];
    titleColor = [UIColor colorWithRed:0.5 green:0.0 blue:0.5 alpha:1.0];

    //*
    [knobControl setFillColor:normalColor forState:UIControlStateNormal];
    [knobControl setFillColor:highlightedColor forState:UIControlStateHighlighted];
    [knobControl setTitleColor:titleColor forState:UIControlStateNormal];
    //*/

    [knobControl addTarget:self action:@selector(dialed:) forControlEvents:UIControlEventValueChanged];
    [_knobHolder addSubview:knobControl];
}

- (void)viewWillAppear:(BOOL)animated
{
    numberDialed = @"";
    _numberLabel.text = @"(number dialed)";
}

- (void)updateKnobImages
{
    if (imageTitle) {
        [knobControl setImage:[UIImage imageNamed:imageTitle] forState:UIControlStateNormal];
        [knobControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-highlighted", imageTitle]] forState:UIControlStateHighlighted];
        [knobControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-disabled", imageTitle]] forState:UIControlStateDisabled];
        knobControl.backgroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@-background", imageTitle]];
    }
    else {
        [knobControl setImage:nil forState:UIControlStateNormal];
        [knobControl setImage:nil forState:UIControlStateHighlighted];
        [knobControl setImage:nil forState:UIControlStateDisabled];
        knobControl.backgroundImage = nil;
    }
}

- (void)dialed:(IOSKnobControl*)sender
{
    numberDialed = [numberDialed stringByAppendingFormat:@"%ld", (long)knobControl.positionIndex];
    _numberLabel.text = numberDialed;
}

- (void)gestureChanged:(UISegmentedControl *)sender
{
    knobControl.gesture = sender.selectedSegmentIndex == 0 ? IKCGOneFingerRotation : IKCGTap;
}

- (void)timeScaleChanged:(UISlider *)sender
{
    knobControl.timeScale = exp(sender.value);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    KCDImageViewController* imageVC = (KCDImageViewController*)segue.destinationViewController;

    // To customize:
    // add your own image(s) here, e.g.:

    // imageVC.titles = @[@"(none)", @"telephone"];
    imageVC.titles = @[@"(none)"];

    imageVC.imageTitle = imageTitle;
    imageVC.delegate = self;
}

- (void)imageChosen:(NSString *)anImageTitle
{
    imageTitle = anImageTitle;
    [self updateKnobImages];
}

@end
