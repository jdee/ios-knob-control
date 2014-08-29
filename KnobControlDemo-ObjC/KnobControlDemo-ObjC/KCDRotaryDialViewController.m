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

@interface KCDRotaryDialViewController()
@property (nonatomic, readonly) UIBezierPath* dialStopShadowPath;
@end

/*
 * This demo exercises the knob control's IKCModeRotaryDial mode. The size of the control
 * limits the size of the finger holes in the control, so in this mode it's recommended
 * to render the control at a large size. In fact, in rotary dial mode, the control
 * enforces a minimum size for this reason.
 * There are two configuration controls as input, directly below the control:
 * - a segmented control to select the gesture; only one-finger rotation and tap are supported in this mode
 * - a time-scale slider for the return animation; this affects the speed of the animation after you release the control
 * Below these are the only output field, a label that displays the number dialed, and a button labeled Images
 * that allows the user to use the dial with a set of images. The default dial images are rendered by the control as in
 * the other modes.
 */
@implementation KCDRotaryDialViewController {
    NSString* numberDialed, *imageTitle;
}

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];

    imageTitle = @"(none)";

    self.knobControl = [[IOSKnobControl alloc] initWithFrame:_knobHolder.bounds];
    self.knobControl.mode = IKCModeRotaryDial;
    self.knobControl.gesture = IKCGestureOneFingerRotation;
    self.knobControl.shadowOpacity = 0.7;
    self.knobControl.clipsToBounds = NO;
    self.knobControl.drawsAsynchronously = YES;

    // self.knobControl.fontName = @"CourierNewPS-BoldMT";
    // self.knobControl.fontName = @"Verdana-Bold";
    // self.knobControl.fontName = @"Georgia-Bold";
    // self.knobControl.fontName = @"TimesNewRomanPS-BoldMT";
    self.knobControl.fontName = @"AvenirNext-Bold";
    // self.knobControl.fontName = @"TrebuchetMS-Bold";

    UIColor* normalColor, *highlightedColor, *titleColor;
    normalColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:0.7];
    highlightedColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:0.7];
    titleColor = [UIColor colorWithRed:0.0 green:0.3 blue:0.0 alpha:1.0];

    //*
    [self.knobControl setFillColor:normalColor forState:UIControlStateNormal];
    [self.knobControl setFillColor:highlightedColor forState:UIControlStateHighlighted];
    [self.knobControl setTitleColor:titleColor forState:UIControlStateNormal];
    //*/

    [self.knobControl addTarget:self action:@selector(dialed:) forControlEvents:UIControlEventValueChanged];
    [_knobHolder addSubview:self.knobControl];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    numberDialed = @"";
    _numberLabel.text = @"(number dialed)";
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    KCDImageViewController* imageVC = (KCDImageViewController*)segue.destinationViewController;

    imageVC.titles = @[@"(none)", @"telephone"];

    imageVC.imageTitle = imageTitle;
    imageVC.delegate = self;
}

#pragma mark - Knob control callback
- (void)dialed:(IOSKnobControl*)sender
{
    numberDialed = [numberDialed stringByAppendingFormat:@"%ld", (long)self.knobControl.positionIndex];
    _numberLabel.text = numberDialed;
}

#pragma mark - Actions for storyboard outlets
- (void)gestureChanged:(UISegmentedControl *)sender
{
    self.knobControl.gesture = sender.selectedSegmentIndex == 0 ? IKCGestureOneFingerRotation : IKCGestureTap;
}

- (void)timeScaleChanged:(UISlider *)sender
{
    /*
     * Using exponentiation avoids compressing the scale below 1.0. The
     * slider starts at 0 in middle and ranges from -1 to 1, so the
     * time scale can range from 1/e to e, and defaults to 1.
     */
    self.knobControl.timeScale = exp(sender.value);
}

#pragma mark - Image chooser delegate
- (void)imageChosen:(NSString *)anImageTitle
{
    imageTitle = anImageTitle;
    [self updateKnobImages];
}

#pragma mark - Internal methods

- (void)updateKnobImages
{
    if (imageTitle) {
        /*
         * As in the ContinuousViewController, if an image set exists starting with the selected title
         * and ending in -highlighted or -disabled, it is used for that state.
         * Image sets ending in -background or -foreground, if any, are used for the background and
         * foreground images.
         */
        [self.knobControl setImage:[UIImage imageNamed:imageTitle] forState:UIControlStateNormal];
        [self.knobControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-highlighted", imageTitle]] forState:UIControlStateHighlighted];
        [self.knobControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-disabled", imageTitle]] forState:UIControlStateDisabled];
        self.knobControl.backgroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@-background", imageTitle]];
        self.knobControl.foregroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@-foreground", imageTitle]];

        self.knobControl.foregroundLayerShadowPath = self.dialStopShadowPath;
    }
    else {
        [self.knobControl setImage:nil forState:UIControlStateNormal];
        [self.knobControl setImage:nil forState:UIControlStateHighlighted];
        [self.knobControl setImage:nil forState:UIControlStateDisabled];
        self.knobControl.backgroundImage = nil;
        self.knobControl.foregroundImage = nil;
    }
}

- (UIBezierPath*)dialStopShadowPath
{
    float const stopWidth = 0.05;

    // the stop is an isosceles triangle at 4:00 (-M_PI/6) pointing inward radially.

    // the near point is the point nearest the center of the dial, at the edge of the
    // outer tap ring. (see handleTap: for where the 0.586 comes from.)

    float nearX = self.knobControl.bounds.size.width*0.5 * (1.0 + 0.586 * sqrt(3.0) * 0.5);
    float nearY = self.knobControl.bounds.size.height*0.5 * (1.0 + 0.586 * 0.5);

    // the opposite edge is tangent to the perimeter of the dial. the width of the far side
    // is stopWidth * self.frame.size.height * 0.5.

    float upperEdgeX = self.knobControl.bounds.size.width*0.5 * (1.0 + sqrt(3.0) * 0.5 + stopWidth * 0.5);
    float upperEdgeY = self.knobControl.bounds.size.height*0.5 * (1.0 + 0.5 - stopWidth * sqrt(3.0)*0.5);

    float lowerEdgeX = self.knobControl.bounds.size.width*0.5 * (1.0 + sqrt(3.0) * 0.5 - stopWidth * 0.5);
    float lowerEdgeY = self.knobControl.bounds.size.height*0.5 * (1.0 + 0.5 + stopWidth * sqrt(3.0)*0.5);

    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(nearX, nearY)];
    [path addLineToPoint:CGPointMake(lowerEdgeX, lowerEdgeY)];
    [path addLineToPoint:CGPointMake(upperEdgeX, upperEdgeY)];
    [path closePath];
    return path;
}

@end
