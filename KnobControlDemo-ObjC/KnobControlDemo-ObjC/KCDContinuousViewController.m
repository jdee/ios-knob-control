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
#import "KCDContinuousViewController.h"
#import "KCDImageViewController.h"

/*
 * The purpose of the continuous tab is to exercise the knob control in IKCModeContinuous mode.
 * There is one primary output field, at the upper right: position. This indicates the angle, in
 * radians, through which the knob has turned from its initial position. There are several
 * further inputs to change the knob's parameters and behavior in continuous mode:
 * - a switch labeled "clockwise" that determines whether the knob considers a positive rotation to be clockwise or counterclockwise
 * - a button labeled "Images" that presents a modal view allowing the user to select images to use with the knob
 * - a segmented control to select which gesture the knob will respond to (1-finger rotation, 2-finger rotation, vertical pan or tap)
 * - a switch labeled "circular" that determines whether the knob can rotate freely all the way around in a circle:
 * -- If this switch is ON, the min and max knob properties are ignored, and the min and max knobs below are disabled
 * -- If this switch is OFF, the position property is constrained to lie between the min and max properties of the knob. The min and
 *    max knob controls are enabled to specify the min and max values of the knob's position property.
 * - min and max knob controls, each with its own output label, reading that control's position as above; the values of these knob positions
 *   are used for the main knob control's min and max properties
 *
 * By setting the circular switch to ON (its default state), you can also exercise the disabled state of the min and max knob controls.
 *
 * Knob controls are always created programmatically and inserted as subviews of placeholder views (usually UIViews, but can be anything).
 */
@implementation KCDContinuousViewController {
    IOSKnobControl* minControl;
    IOSKnobControl* maxControl;
    NSString* imageTitle;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    imageTitle = @"(none)";

    // basic continuous knob configuration
    self.knobControl = [[IOSKnobControl alloc] initWithFrame:self.knobControlView.bounds];
    self.knobControl.mode = IKCModeContinuous;
    self.knobControl.shadowOpacity = 1.0;
    self.knobControl.clipsToBounds = NO;
    // NOTE: This is an important optimization when using a custom circular knob image with a shadow.
    self.knobControl.knobRadius = 0.475 * self.knobControl.bounds.size.width;

    // arrange to be notified whenever the knob turns
    [self.knobControl addTarget:self action:@selector(knobPositionChanged:) forControlEvents:UIControlEventValueChanged];

    // Now hook it up to the demo
    [self.knobControlView addSubview:self.knobControl];

    [self setupMinAndMaxControls];

    [self updateKnobProperties];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateKnobProperties];

    NSLog(@"Min. knob position %f, max. knob position %f", minControl.position, maxControl.position);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // this is our only segue, so be lazy
    KCDImageViewController* imageVC = (KCDImageViewController*)segue.destinationViewController;
    imageVC.titles = @[@"(none)", @"knob", @"teardrop"];
    imageVC.imageTitle = imageTitle;
    imageVC.delegate = self;
}

#pragma mark - Knob control callback
- (void)knobPositionChanged:(IOSKnobControl*)sender
{
    if (sender == self.knobControl) {
        self.positionLabel.text = [NSString stringWithFormat:@"%.2f", self.knobControl.position];
    }
    else if (sender == minControl) {
        self.minLabel.text = [NSString stringWithFormat:@"%.2f", minControl.position];
        self.knobControl.min = minControl.position;
    }
    else if (sender == maxControl) {
        self.maxLabel.text = [NSString stringWithFormat:@"%.2f", maxControl.position];
        self.knobControl.max = maxControl.position;
    }
}

#pragma mark - Image chooser delegate
- (void)imageChosen:(NSString *)anImageTitle
{
    imageTitle = anImageTitle;
    [self updateKnobImages];
}

#pragma mark - Handler for configuration controls

- (void)somethingChanged:(id)sender
{
    [self updateKnobProperties];
}

#pragma mark - Internal methods

- (void)updateKnobImages
{
    if (imageTitle) {
        /*
         * If an imageTitle is specified, take that image set from the asset catalog and use it for
         * the UIControlState.Normal state. If images are not specified (or are set to nil) for other
         * states, the image for the .Normal state will be used for the knob.
         * If image sets exist beginning with the specified imageTitle and ending with -highlighted or
         * -disabled, those images will be used for the relevant states. If there is no such image set
         * in the asset catalog, the image for that state will be set to nil here.
         * If image sets exist beginning with the specified imageTitle and ending with -foreground or
         * -background, they will be used for the foregroundImage or backgroundImage properties,
         * respectively, of the control. These are mainly used for rotary dial mode and are mostly
         * absent here (nil).
         */
        [self.knobControl setImage:[UIImage imageNamed:imageTitle] forState:UIControlStateNormal];
        [self.knobControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-highlighted", imageTitle]] forState:UIControlStateHighlighted];
        [self.knobControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-disabled", imageTitle]] forState:UIControlStateDisabled];
        self.knobControl.backgroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@-background", imageTitle]];
        self.knobControl.foregroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@-foreground", imageTitle]];

        // Use the same three images for each knob.
        [minControl setImage:[UIImage imageNamed:imageTitle] forState:UIControlStateNormal];
        [minControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-highlighted", imageTitle]] forState:UIControlStateHighlighted];
        [minControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-disabled", imageTitle]] forState:UIControlStateDisabled];
        minControl.backgroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@-background", imageTitle]];
        minControl.foregroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@-foreground", imageTitle]];

        [maxControl setImage:[UIImage imageNamed:imageTitle] forState:UIControlStateNormal];
        [maxControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-highlighted", imageTitle]] forState:UIControlStateHighlighted];
        [maxControl setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@-disabled", imageTitle]] forState:UIControlStateDisabled];
        maxControl.backgroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@-background", imageTitle]];
        maxControl.foregroundImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@-foreground", imageTitle]];

        if ([imageTitle isEqualToString:@"teardrop"]) {
            self.knobControl.knobRadius = 0.0;
        }
    }
    else {
        /*
         * If no imageTitle is specified, set all these things to nil to use the default images
         * generated by the control.
         */
        [self.knobControl setImage:nil forState:UIControlStateNormal];
        [self.knobControl setImage:nil forState:UIControlStateHighlighted];
        [self.knobControl setImage:nil forState:UIControlStateDisabled];
        self.knobControl.backgroundImage = nil;
        self.knobControl.foregroundImage = nil;

        [minControl setImage:nil forState:UIControlStateNormal];
        [minControl setImage:nil forState:UIControlStateHighlighted];
        [minControl setImage:nil forState:UIControlStateDisabled];
        minControl.backgroundImage = nil;
        minControl.foregroundImage = nil;

        [maxControl setImage:nil forState:UIControlStateNormal];
        [maxControl setImage:nil forState:UIControlStateHighlighted];
        [maxControl setImage:nil forState:UIControlStateDisabled];
        maxControl.backgroundImage = nil;
        maxControl.foregroundImage = nil;

        self.knobControl.knobRadius = 0.475 * self.knobControl.bounds.size.width;
    }
}

- (void)updateKnobProperties
{
    self.knobControl.circular = self.circularSwitch.on;
    self.knobControl.min = minControl.position;
    self.knobControl.max = maxControl.position;
    self.knobControl.clockwise = self.clockwiseSwitch.on;

    if ([self.knobControl respondsToSelector:@selector(setTintColor:)]) {
        // configure the tint color (iOS 7+ only)

        // minControl.tintColor = maxControl.tintColor = self.knobControl.tintColor = [UIColor greenColor];
        // minControl.tintColor = maxControl.tintColor = self.knobControl.tintColor = [UIColor blackColor];
        // minControl.tintColor = maxControl.tintColor = self.knobControl.tintColor = [UIColor whiteColor];

        // minControl.tintColor = maxControl.tintColor = self.knobControl.tintColor = [UIColor colorWithRed:0.627 green:0.125 blue:0.941 alpha:1.0];
        minControl.tintColor = maxControl.tintColor = self.knobControl.tintColor = [UIColor colorWithHue:0.5 saturation:1.0 brightness:1.0 alpha:1.0];
    }
    else {
        // can still customize piecemeal below iOS 7
        UIColor* titleColor = [UIColor whiteColor];
        [minControl setTitleColor:titleColor forState:UIControlStateNormal];
        [maxControl setTitleColor:titleColor forState:UIControlStateNormal];
        [self.knobControl setTitleColor:titleColor forState:UIControlStateNormal];
    }

    minControl.gesture = maxControl.gesture = self.knobControl.gesture = IKCGestureOneFingerRotation + self.gestureControl.selectedSegmentIndex;

    minControl.clockwise = maxControl.clockwise = self.knobControl.clockwise;

    minControl.position = minControl.position;
    maxControl.position = maxControl.position;

    // Good idea to do this to make the knob reset itself after changing certain params.
    self.knobControl.position = self.knobControl.position;

    minControl.enabled = maxControl.enabled = self.circularSwitch.on == NO;
}

- (void)setupMinAndMaxControls
{
    // Both controls use the same image in continuous mode with circular set to NO. The clockwise
    // property is set to the same value as the main knob (the value of self.clockwiseSwitch.on).
    // That happens in updateKnobProperties.
    minControl = [[IOSKnobControl alloc] initWithFrame:self.minControlView.bounds];
    maxControl = [[IOSKnobControl alloc] initWithFrame:self.maxControlView.bounds];

    minControl.mode = maxControl.mode = IKCModeContinuous;
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

@end
