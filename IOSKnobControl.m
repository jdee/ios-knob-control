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

/*
 * Return animations rotate through this many radians per second when self.timeScale == 1.0.
 */
#define IKC_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE 0.52359878163217 // M_PI/6.0 rad/s
/*
 * Rotary dial animations are 10 times faster.
 */
#define IKC_ROTARY_DIAL_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE 5.2359878163217 // 5.0*M_PI/3.0 rad/s
#define IKC_EPSILON 1e-7

// Must match IKC_VERSION and IKC_BUILD from IOSKnobControl.h.
#define IKC_TARGET_VERSION 0x010200
#define IKC_TARGET_BUILD 1

/*
 * DEBT: Should also do a runtime check in the constructors in case the control is ever built
 * into a library.
 */
#if IKC_TARGET_VERSION != IKC_VERSION || IKC_TARGET_BUILD != IKC_BUILD
#error IOSKnobControl.h version and build do not match IOSKnobControl.m.
#endif // target version/build check

static float normalizePosition(float position) {
    while (position >   M_PI) position -= 2.0*M_PI;
    while (position <= -M_PI) position += 2.0*M_PI;

    return position;
}

static int numberDialed(float position) {
    // normalize position to [0, 2*M_PI)
    while (position < 0) position += 2.0*M_PI;
    while (position >= 2.0*M_PI) position -= 2.0*M_PI;

    // now number is in [0, 11]
    int number = position * 6.0 / M_PI;

    // this is not 0 but the dead spot clockwise from 1
    if (number == 0) return 12;
    // this is the next dead spot, counterclockwise from 0
    if (number == 11) return 11;

    // now number is in [1, 10]. the modulus makes 1..10 into 1..9, 0.
    // the return value is in [0, 9].
    return number % 10;
}

@protocol NSStringDeprecatedMethods
- (CGSize)sizeWithFont:(UIFont*)font;
@end

@interface NSString(IKC)
- (CGSize)sizeOfTextWithFontSize:(CGFloat)fontSize;
@end

@implementation NSString(IKC)

/*
 * For portability among iOS versions. The CATextLayer uses Helvetica
 * by default. We just need the font size here.
 */
- (CGSize)sizeOfTextWithFontSize:(CGFloat)fontSize
{
    CGSize textSize;
    UIFont* font = [UIFont fontWithName:@"Helvetica" size:fontSize];
    if ([self respondsToSelector:@selector(sizeWithAttributes:)]) {
        // iOS 7.x
        NSMutableDictionary* attrs = [NSMutableDictionary dictionary];
        [attrs setObject:font forKey:NSFontAttributeName];
        textSize = [self sizeWithAttributes:attrs];
    }
    else {
        // iOS 5 & 6
        // following http://vgable.com/blog/2009/06/15/ignoring-just-one-deprecated-warning/
        id<NSStringDeprecatedMethods> string = (id<NSStringDeprecatedMethods>)self;
        textSize = [string sizeWithFont:font];
    }
    return textSize;
}

@end

@interface IOSKnobControl()
/*
 * Returns the nearest allowed position
 */
@property (readonly) float nearestPosition;
@end

@implementation IOSKnobControl {
    float touchStart, positionStart, currentTouch;
    UIGestureRecognizer* gestureRecognizer;
    CALayer* imageLayer, *backgroundLayer;
    CAShapeLayer* shapeLayer, *pipLayer;
    NSMutableArray* markings, *dialMarkings;
    UIImage* images[4];
    UIColor* fillColor[4];
    UIColor* titleColor[4];
    BOOL rotating;
    int lastNumberDialed, _numberDialed;
}

@dynamic positionIndex, nearestPosition;

#pragma mark - Object Lifecycle

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setDefaults];
        [self setupGestureRecognizer];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame image:(UIImage *)image
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setImage:image forState:UIControlStateNormal];
        [self setDefaults];
        [self setupGestureRecognizer];
        [self updateImage];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame imageNamed:(NSString *)imageSetName
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImage* image = [UIImage imageNamed:imageSetName];
        [self setImage:image forState:UIControlStateNormal];
        [self setDefaults];
        [self setupGestureRecognizer];
        [self updateImage];
    }
    return self;
}

- (void)setDefaults
{
    _mode = IKCMLinearReturn;
    _clockwise = NO;
    _position = 0.0;
    _circular = YES;
    _min = -M_PI + IKC_EPSILON;
    _max = M_PI - IKC_EPSILON;
    _positions = 2;
    _timeScale = 1.0;
    _gesture = IKCGOneFingerRotation;

    rotating = NO;
    lastNumberDialed = _numberDialed = -1;

    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;
}

#pragma mark - Public Methods, Properties and Overrides

- (UIImage *)imageForState:(UIControlState)state
{
    int index = [self indexForState:state];
    /*
     * Like UIButton, use the image for UIControlStateNormal if none present.
     */
    // Mmmm. Double square brackets in the last expression of the ternary conditional: outer for the array subscript, inner for a method call.
    return index >= 0 && images[index] ? images[index] : images[[self indexForState:UIControlStateNormal]];
}

- (void)setImage:(UIImage *)image forState:(UIControlState)state
{
    int index = [self indexForState:state];
    /*
     * Don't accept mixed states here. Cannot pass, e.g., UIControlStateHighlighted & UIControlStateDisabled.
     * Those values are ignored here.
     */
    if (state == UIControlStateNormal || state == UIControlStateHighlighted || state == UIControlStateDisabled || state == UIControlStateSelected) {
        images[index] = image;
    }

    /*
     * The method parameter state must be one of the four enumerated values listed above.
     * But self.state could be a mixed state. Conceivably, the control could be
     * both disabled and highlighted. In that case, since disabled is numerically
     * greater than highlighted, we return the index/image for UIControlStateDisabled.
     * (See indexForState: below.) That is to say, the following expression is always true:
     * [self indexForState:UIControlStateDisabled] == [self indexForState:UIControlStateHighlighted|UIControlStateDisabled]
     * If we just now changed the image currently in use (the image for the current state), update it now.
     */
    if (index == [self indexForState:self.state]) {
        [self updateImage];
    }
}

- (UIColor *)fillColorForState:(UIControlState)state
{
    int index = [self indexForState:state];
    UIColor* color = index >= 0 && fillColor[index] ? fillColor[index] : fillColor[[self indexForState:UIControlStateNormal]];

    if (!color) {
        CGFloat red, green, blue, alpha;
        [self.getTintColor getRed:&red green:&green blue:&blue alpha:&alpha];

        CGFloat hue, saturation, brightness;
        [self.getTintColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

        if ((red == green && green == blue) || brightness < 0.02) {
            /*
             * This is for any shade of gray from black to white. Unfortunately, black is not really black.
             * It comes out as a red hue. Hence the brightness test above.
             */
            CGFloat value = ((NSNumber*)@[@(0.6), @(0.8), @(0.9), @(0.8)][index]).floatValue;
            color = [UIColor colorWithRed:value green:value blue:value alpha:alpha];
        }
        else {
            saturation = ((NSNumber*)@[@(1.0), @(0.7), @(0.2), @(0.7)][index]).floatValue;
            brightness = ((NSNumber*)@[@(0.9), @(1.0), @(0.9), @(1.0)][index]).floatValue;
            color = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
        }
    }

    return color;
}

- (void)setFillColor:(UIColor *)color forState:(UIControlState)state
{
    int index = [self indexForState:state];
    if (state == UIControlStateNormal || state == UIControlStateHighlighted || state == UIControlStateDisabled || state == UIControlStateSelected) {
        fillColor[index] = color;
    }

    if (index == [self indexForState:self.state]) {
        [self updateImage];
    }
}

- (UIColor *)titleColorForState:(UIControlState)state
{
    int index = [self indexForState:state];
    UIColor* color = index >= 0 && titleColor[index] ? titleColor[index] : titleColor[[self indexForState:UIControlStateNormal]];

    if (!color) {
        CGFloat red, green, blue, alpha;
        [self.getTintColor getRed:&red green:&green blue:&blue alpha:&alpha];

        CGFloat hue, saturation, brightness;
        [self.getTintColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

        if ((red == green && green == blue) || brightness < 0.02) {
            /*
             * This is for any shade of gray from black to white. Unfortunately, black is not really black.
             * It comes out as a red hue. Hence the brightness test above.
             */
            CGFloat value = ((NSNumber*)@[@(0.25), @(0.25), @(0.4), @(0.25)][index]).floatValue;
            color = [UIColor colorWithRed:value green:value blue:value alpha:alpha];
        }
        else {
            saturation = ((NSNumber*)@[@(1.0), @(1.0), @(0.2), @(1.0)][index]).floatValue;
            brightness = 0.5; // ((NSNumber*)@[@(0.5), @(0.5), @(0.5), @(0.5)][index]).floatValue;
            color = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
        }
    }

    return color;
}

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state
{
    int index = [self indexForState:state];
    if (state == UIControlStateNormal || state == UIControlStateHighlighted || state == UIControlStateDisabled || state == UIControlStateSelected) {
        titleColor[index] = color;
    }

    if (index == [self indexForState:self.state]) {
        [self updateImage];
    }
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    _backgroundImage = backgroundImage;
    [self updateImage];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    gestureRecognizer.enabled = enabled;

    [self updateImage];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self updateImage];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self updateImage];
}

- (void)setPositions:(NSUInteger)positions
{
    _positions = positions;
    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self.layer addSublayer:imageLayer];
}

- (void)setTitles:(NSArray *)titles
{
    /*
     * DEBT: Actually, titles can be set on a control using images. It's the absence of the
     * image that triggers use of the titles. The property can be populated in advance of
     * removing images.
     */
    _titles = titles;
    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self.layer addSublayer:imageLayer];
}

- (void)setMode:(IKCMode)mode
{
    _mode = mode;
    [self updateImage];

    if (_mode == IKCMRotaryDial)
    {
        if (_gesture == IKCGVerticalPan || _gesture == IKCGTwoFingerRotation)
        {
            self.gesture = IKCGOneFingerRotation;
        }
        self.clockwise = NO; // dial clockwise, but all calcs assume ccw
        self.circular = YES; // these two settings affect how position is read out while dialing and how
    }
}

- (void)setCircular:(BOOL)circular
{
    if (_mode == IKCMRotaryDial) return;
    _circular = circular;
}

- (void)setClockwise:(BOOL)clockwise
{
    if (_mode == IKCMRotaryDial) return;

    _clockwise = clockwise;
    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self.layer addSublayer:imageLayer];
    [self updateImage];
}

- (void)setPosition:(float)position
{
    [self setPosition:position animated:NO];
}

- (void)setPosition:(float)position animated:(BOOL)animated
{
    // for this purpose, don't normalize to [-M_PI,M_PI].
    if (_circular == NO) {
        position = MAX(position, _min);
        position = MIN(position, _max);
    }
    float delta = fabs(position - _position);

    // ignore _timeScale. rotate through 2*M_PI in 1 s.
    [self returnToPosition:position duration:animated ? delta*0.5/M_PI : 0.0];
}

- (void)setPositionIndex:(NSInteger)positionIndex
{
    if (self.mode == IKCMContinuous) return;

    float position = self.circular ? (2.0*M_PI/_positions)*positionIndex : ((self.max - self.min)/_positions)*(positionIndex+0.5) + self.min;
    [self setPosition:position animated:NO];
}

- (NSInteger)positionIndex
{
    if (self.mode == IKCMContinuous) return -1;
    if (self.mode == IKCMRotaryDial) return lastNumberDialed;

    if (!_circular && _position == _max) {
        return _positions - 1;
    }

    float converted = self.position;
    if (converted < 0) converted += 2.0*M_PI;

    int index = self.circular ? converted*0.5/M_PI*self.positions+0.5 : (self.position-self.min)/(self.max-self.min)*self.positions;

    while (index >= self.positions) index -= self.positions;
    while (index < 0) index += self.positions;

    return index;
}

/*
 * This override is to fix #3.
 */
- (BOOL)isHighlighted
{
    return rotating || [super isHighlighted];
}

- (void)setMin:(float)min
{
    min = normalizePosition(min);
    if (min > 0.0) min = 0.0;
    if (min <= -M_PI) min = -M_PI + IKC_EPSILON;
    _min = min;

    if (_mode == IKCMContinuous || self.currentImage) return;

    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self.layer addSublayer:imageLayer];
    [self updateImage];
}

- (void)setMax:(float)max
{
    max = normalizePosition(max);
    if (max < 0.0) max = 0.0;
    if (max >= M_PI) max = M_PI - IKC_EPSILON;
    _max = max;

    if (_mode == IKCMContinuous || self.currentImage) return;

    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self.layer addSublayer:imageLayer];
    [self updateImage];
}

- (void)setGesture:(IKCGesture)gesture
{
    if (_mode == IKCMRotaryDial && (gesture == IKCGTwoFingerRotation || gesture == IKCGVerticalPan))
    {
#ifdef DEBUG
        NSLog(@"IKCMRotaryDial only allows IKCGOneFingerRotation and IKCGTap");
#endif // DEBUG
        return;
    }

    _gesture = gesture;
    [self setupGestureRecognizer];
}

- (void)tintColorDidChange
{
    if ([imageLayer isKindOfClass:CAShapeLayer.class]) {
        [self updateShapeLayer];
    }
}

- (UIImage*)currentImage
{
    return [self imageForState:self.state];
}

- (UIColor*)currentFillColor
{
    return [self fillColorForState:self.state];
}

- (UIColor*)currentTitleColor
{
    return [self titleColorForState:self.state];
}

- (void)dialNumber:(int)number
{
    if (_mode != IKCMRotaryDial) return;
    if (number < 0 || number > 9) return;

    lastNumberDialed = number;
    [self sendActionsForControlEvents:UIControlEventValueChanged];

    if (number == 0) number = 10;

    // now animate

    double farPosition = (number + 1) * M_PI/6.0;
    double adjusted = -_position;
    while (adjusted < 0) adjusted += 2.0*M_PI;
    double totalRotation = 2.0*farPosition - adjusted;

    [CATransaction new];
    [CATransaction setDisableActions:YES];
    imageLayer.transform = CATransform3DMakeRotation(0.0, 0, 0, 1);
    _position = 0.0;

    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    animation.values = @[@(adjusted), @(farPosition), @(0.0)];
    animation.keyTimes = @[@(0.0), @((farPosition-adjusted)/totalRotation), @(1.0)];
    animation.duration = _timeScale / IKC_ROTARY_DIAL_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE * totalRotation;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

    [imageLayer addAnimation:animation forKey:nil];

    [CATransaction commit];
}

#pragma mark - Private Methods: Geometry

- (CGPoint)transformLocationToCenterFrame:(CGPoint)point
{
    point.x -= self.bounds.size.width*0.5;
    point.y = self.bounds.size.height*0.5 - point.y;
    return point;
}

- (CGPoint)transformTranslationToCenterFrame:(CGPoint)point
{
    point.y = -point.y;
    return point;
}

// returns a number in [-M_PI,M_PI]
- (double)polarAngleOfPoint:(CGPoint)point
{
    return atan2(point.y, self.clockwise ? -point.x : point.x);
}

/*
 * Not normalized to (-M_PI,M_PI].
 */
- (float)nearestPosition
{
    if (_circular) {
        if (2*self.positionIndex == self.positions) {
            /*
             * Try to keep things confined to (-M_PI,M_PI] and avoid a return to -M_PI.
             * This only happens when circular is YES.
             * https://github.com/jdee/ios-knob-control/issues/7
             */
            return M_PI - IKC_EPSILON;
        }
        return self.positionIndex*2.0*M_PI/_positions;
    }

    return ((_max-_min)/_positions)*(self.positionIndex+0.5) + _min;
}

#pragma mark - Private Methods: Animation

- (void)snapToNearestPosition
{
    [self snapToNearestPositionWithDuration:-1.0];
}

- (void)snapToNearestPositionWithDuration:(float)duration
{
    /*
     * Animate return to nearest position
     */
    float nearestPositionAngle = self.nearestPosition;
    float delta = nearestPositionAngle - self.position;

    while (delta > M_PI) {
        nearestPositionAngle -= 2.0*M_PI;
        delta -= 2.0*M_PI;
    }
    while (delta <= -M_PI) {
        nearestPositionAngle += 2.0*M_PI;
        delta += 2.0*M_PI;
    }

    // DEBT: Make these constants macros, properties, something.
    const float threshold = 0.9*M_PI/self.positions;

    switch (self.mode) {
        case IKCMWheelOfFortune:
            // Exclude the outer 10% of each segment. Otherwise, like continuous mode.
            // If it has to be returned to the interior of the segment, the animation
            // is the same as the slow return animation, but it returns to the nearest
            // edge of the segment interior, not the center of the segment.

            if (delta > threshold) {
                delta -= threshold;
                nearestPositionAngle -= threshold;
            }
            else if (delta < -threshold) {
                delta += threshold;
                nearestPositionAngle += threshold;
            }
            else {
                // there's no animation, no snap; WoF is like continuous mode except at the boundaries
                return;
            }
            break;
        default:
            break;
    }

    if (duration < 0.0)
    {
        duration = _timeScale/IKC_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE*fabs(delta);
    }

    [self returnToPosition:nearestPositionAngle duration:duration];
}

- (void)returnToPosition:(float)position duration:(float)duration
{
    float actual = self.clockwise ? position : -position;
    float current = self.clockwise ? self.position : -self.position;

    if (duration > 0.0) {
        // The largest absolute value of delta is M_PI/self.positions, halfway between segments.
        // If delta is M_PI/self.positions, the duration is maximal. Otherwise, it scales linearly.
        // Without this adjustment, the animation will seem much faster for large
        // deltas.

        // Gratefully borrowed from http://www.raywenderlich.com/56885/custom-control-for-ios-tutorial-a-reusable-knob
        [CATransaction new];
        [CATransaction setDisableActions:YES];
        imageLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);

        // Provide an animation
        // Key-frame animation to ensure rotates in correct direction
        CGFloat midAngle = 0.5*(actual+current);
        CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
        animation.values = @[@(current), @(midAngle), @(actual)];
        animation.keyTimes = @[@(0.0), @(0.5), @(1.0)];
        animation.duration = duration;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

        [imageLayer addAnimation:animation forKey:nil];
        
        [CATransaction commit];
    }
    else {
        imageLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);
    }

    _position = normalizePosition(position);
    if (_mode != IKCMRotaryDial)
    {
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

#pragma mark - Private Methods: Gesture Recognition

- (void)setupGestureRecognizer
{
    if (gestureRecognizer) [self removeGestureRecognizer:gestureRecognizer];

    if (_gesture == IKCGOneFingerRotation) {
        gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    }
    else if (_gesture == IKCGTwoFingerRotation) {
        gestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation:)];
    }
    else if (_gesture == IKCGVerticalPan) {
        gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleVerticalPan:)];
    }
    else if (_gesture == IKCGTap)
    {
        gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    }

    gestureRecognizer.enabled = self.enabled;
    [self addGestureRecognizer:gestureRecognizer];
}

// DEBT: Factor this stuff into a separate GR?
- (void)handlePan:(UIPanGestureRecognizer *)sender
{
    // most recent position of touch in center frame of control.
    CGPoint centerFrameBegin = [self transformLocationToCenterFrame:[sender locationInView:self]];
    CGPoint centerFrameTranslation = [self transformTranslationToCenterFrame:[sender translationInView:self]];
    CGPoint centerFrameEnd = centerFrameBegin;
    centerFrameEnd.x += centerFrameTranslation.x;
    centerFrameEnd.y += centerFrameTranslation.y;
    float touch = [self polarAngleOfPoint:centerFrameEnd];

    if (sender.state == UIGestureRecognizerStateBegan) {
        touchStart = touch;
        positionStart = self.position;
        currentTouch = touch;
        _numberDialed = numberDialed([self polarAngleOfPoint:centerFrameBegin]);
    }

    if (currentTouch > M_PI_2 && currentTouch < M_PI && touch < -M_PI_2 && touch > -M_PI) {
        // sudden jump from 2nd to 3rd quadrant. preserve continuity of the gesture by adjusting touchStart.
        touchStart -= 2.0*M_PI;
    }
    else if (currentTouch < -M_PI_2 && currentTouch > -M_PI && touch > M_PI_2 && touch < M_PI) {
        // sudden jump from 3rd to 2nd quadrant. preserve continuity of the gesture by adjusting touchStart.
        touchStart += 2.0*M_PI;
    }

    float position = positionStart + touch - touchStart;

    currentTouch = touch;

    /*
    NSLog(@"knob turned. state = %s, touchStart = %f, positionStart = %f, touch = %f, position = %f",
          (sender.state == UIGestureRecognizerStateBegan ? "began" :
           sender.state == UIGestureRecognizerStateChanged ? "changed" :
           sender.state == UIGestureRecognizerStateEnded ? "ended" : "<misc>"), touchStart, positionStart, touch, position);
    //*/

    [self followGesture:sender toPosition:position];
}

- (void)handleRotation:(UIRotationGestureRecognizer*)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        positionStart = self.position;
    }

    float sign = self.clockwise ? 1.0 : -1.0;

    [self followGesture:sender toPosition:positionStart + sign * sender.rotation];
}

- (void)handleVerticalPan:(UIPanGestureRecognizer*)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        positionStart = self.position;
    }

    // 1 vertical pass over the control bounds = 1 radian
    // DEBT: Might want to make this sensitivity configurable.
    float position = positionStart - [sender translationInView:self].y/self.bounds.size.height;
    [self followGesture:sender toPosition:position];
}

- (void)handleTap:(UITapGestureRecognizer*)sender
{
    if (sender.state != UIGestureRecognizerStateEnded) return;

    CGPoint location = [sender locationInView:self];
    CGPoint inCenterFrame = [self transformLocationToCenterFrame:location];
    float position = [self polarAngleOfPoint:inCenterFrame];

    switch (self.mode)
    {
        case IKCMContinuous:
            // DEBT: This is the first gesture that provides an absolute position. Previously all gestures
            // only rotated the image *by* a certain amount. This gesture rotates the image *to* a specific
            // position. This assumes a certain orientation of the image. For now, assume the pointer is
            // at the top.
            self.position = position - M_PI_2;
            break;
        case IKCMLinearReturn:
        case IKCMWheelOfFortune:
            // DEBT: And that works poorly with discrete modes. If I tap Feb, it doesn't mean I want Jan to
            // rotate to that point. It means I want Feb at the top. Things would work the same as the
            // continuous mode if you had discrete labels and something like the continuous knob image.
            // For now:
            // DEBT: Blech. Don't want to generate UIControlEventValueChanged twice. Don't call setPosition:.
            // Just adjust the ivar to prep snapToNearest.... This could use work.
            // All I really need is something like [self nearestPositionToPosition:]. 怠け者だな。
            _position -= position - M_PI_2;
            [self snapToNearestPositionWithDuration:0.0];
            break;
        case IKCMRotaryDial:
            // This is the reason this gesture was introduced. The user can simply tap a number on the dial,
            // and the dial will rotate around and back as though they had dialed.
            [self dialNumber:numberDialed(position)];
            break;
        default:
            break;
    }
}

- (void)followGesture:(UIGestureRecognizer*)sender toPosition:(double)position
{
    switch (sender.state) {
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
            if (self.mode == IKCMLinearReturn || self.mode == IKCMWheelOfFortune)
            {
                [self snapToNearestPosition];
            }
            else if (self.mode == IKCMRotaryDial)
            {
                double delta = normalizePosition(currentTouch - touchStart);
                // delta is signed and will be negative when the dial is rotated clockwise.
                // DEBT: Review, externalize this threshold?
                if (_numberDialed < 0 || _numberDialed > 9 || delta > -M_PI_4)
                {
                    [self returnToPosition:0.0 duration:_timeScale/IKC_ROTARY_DIAL_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE*fabs(position)];
                }
                else
                {
                    [self dialNumber:_numberDialed];
                }
            }

            rotating = NO;

            // revert from highlighted to normal
            [self updateImage];
            break;
        default:
            // just track the touch while the gesture is in progress
            self.position = position;
            if (rotating == NO) {
                rotating = YES;
            }
            break;
    }
}

#pragma mark - Private Methods: Image Management

- (UIColor*)getTintColor
{
    /*
     * No tintColor below iOS 7. This simplifies some internal code.
     */
    if ([self respondsToSelector:@selector(tintColor)]) {
        return self.tintColor;
    }

    return [UIColor blueColor];
}

/*
 * Private method used by imageForState: and setImage:forState:.
 * For a pure state (only one bit set) other than normal, returns that bit + 1. If no
 * bits set, returns 0. If more than one bit set, returns the
 * index corresponding to the highest bit. So for state == UIControlStateNormal,
 * returns 0. For state == UIControlStateDisabled, returns 2. For
 * state == UIControlStateDisabled | UIControlStateSelected, returns 3.
 * Does not currently support UIControlStateApplication. Returns -1 if those bits are set.
 */
- (int)indexForState:(UIControlState)state
{
    if ((state & UIControlStateApplication) != 0) return -1;
    if ((state & UIControlStateSelected) != 0) return 3;
    if ((state & UIControlStateDisabled) != 0) return 2;
    if ((state & UIControlStateHighlighted) != 0) return 1;
    return 0;
}

/*
 * Sets the current image. Not directly called by clients.
 */
- (void)updateImage
{
    /*
     * There is always a background layer. It may just have no contents and no
     * sublayers.
     */
    if (!backgroundLayer)
    {
        backgroundLayer = [CALayer layer];
        backgroundLayer.frame = self.frame;
        backgroundLayer.backgroundColor = [UIColor clearColor].CGColor;
        backgroundLayer.opaque = NO;
        [self.layer addSublayer:backgroundLayer];
    }

    if (_backgroundImage)
    {
        backgroundLayer.contents = (id)_backgroundImage.CGImage;
        for (CALayer* layer in dialMarkings)
        {
            [layer removeFromSuperlayer];
        }
        dialMarkings = nil;
    }
    else if (_mode == IKCMRotaryDial)
    {
        [self createDialNumbers];
    }
    else
    {
        backgroundLayer.contents = nil;
        for (CALayer* layer in dialMarkings)
        {
            [layer removeFromSuperlayer];
        }
        dialMarkings = nil;
    }

    UIImage* image = self.currentImage;
    if (image) {
        if ([imageLayer isKindOfClass:CAShapeLayer.class]) {
            [imageLayer removeFromSuperlayer];
            imageLayer = nil;
        }

        if (!imageLayer) {
            imageLayer = [CALayer layer];
            imageLayer.frame = self.frame;
            imageLayer.backgroundColor = [UIColor clearColor].CGColor;
            imageLayer.opaque = NO;

            float actual = self.clockwise ? self.position : -self.position;
            imageLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);

            [self.layer addSublayer:imageLayer];
        }

        imageLayer.contents = (id)image.CGImage;
    }
    else {
        if (![imageLayer isKindOfClass:CAShapeLayer.class]) {
            [imageLayer removeFromSuperlayer];
            imageLayer = [self createShapeLayer];
            [self.layer addSublayer:imageLayer];
        }
        [self updateShapeLayer];
    }
}

- (void)updateShapeLayer
{
    shapeLayer.fillColor = [self fillColorForState:self.state].CGColor;
    pipLayer.fillColor = [self titleColorForState:self.state].CGColor;

    for (CATextLayer* layer in markings) {
        layer.foregroundColor = [self titleColorForState:self.state].CGColor;
    }

    for (CATextLayer* layer in dialMarkings)
    {
        layer.foregroundColor = [self titleColorForState:self.state].CGColor;
    }
}

- (void)addMarkings
{
    markings = [NSMutableArray array];
    for (CATextLayer* layer in markings) {
        [layer removeFromSuperlayer];
    }

    CGFloat fontSize = self.fontSizeForTitles;
    int j;
    for (j=0; j<_positions; ++j) {
        // get the title for this marking (use j if none)
        NSString* title;
        if (j < _titles.count) title = [_titles objectAtIndex:j];

        if (!title) {
            title = [NSString stringWithFormat:@"%d", j];
        }

        // create a CATextLayer to display this string
        CATextLayer* layer = [CATextLayer layer];
        layer.string = title;
        layer.alignmentMode = kCAAlignmentCenter;

        // set the font size and calculate the size of the title
        layer.fontSize = fontSize;

        CGSize textSize = [layer.string sizeOfTextWithFontSize:layer.fontSize];

        // place it at the appropriate angle, taking the clockwise switch into account
        float position;
        if (self.circular) {
            position = (2.0*M_PI/_positions)*j;
        }
        else {
            position = ((self.max-self.min)/_positions)*(j+0.5) + self.min;
        }

        float actual = self.clockwise ? -position : position;

        // distance from the center to place the upper left corner
        float radius = 0.4*self.bounds.size.width - 0.5*textSize.height;

        // place and rotate
        layer.frame = CGRectMake((0.5*self.bounds.size.width+radius*sin(actual))-0.5*textSize.width, (0.5*self.bounds.size.height-radius*cos(actual))-0.5*textSize.height, textSize.width, textSize.height);
        layer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);

        // background is transparent
        layer.opaque = NO;
        layer.backgroundColor = [UIColor clearColor].CGColor;

        [markings addObject:layer];

        [shapeLayer addSublayer:layer];
    }
}

/*
 * When no image is supplied (when [self imageForState:UIControlStateNormal] returns nil),
 * use a CAShapeLayer instead.
 */
- (CAShapeLayer*)createShapeLayer
{
    if (!shapeLayer) {
        switch (_mode)
        {
            case IKCMContinuous:
                [self createKnobWithPip];
                break;
            case IKCMLinearReturn:
            case IKCMWheelOfFortune:
                [self createKnobWithMarkings];
                break;
            case IKCMRotaryDial:
                [self createRotaryDial];
                break;
#ifdef DEBUG
            default:
                NSLog(@"Unexpected mode: %d", _mode);
                abort();
#endif // DEBUG
        }

        float actual = self.clockwise ? self.position : -self.position;
        shapeLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);
    }

    return shapeLayer;
}

- (CAShapeLayer*)createKnobWithPip
{
    shapeLayer = [CAShapeLayer layer];
    shapeLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5) radius:self.bounds.size.width*0.45 startAngle:0.0 endAngle:2.0*M_PI clockwise:NO].CGPath;
    shapeLayer.frame = self.frame;
    shapeLayer.backgroundColor = [UIColor clearColor].CGColor;
    shapeLayer.opaque = NO;

    for (CATextLayer* layer in markings) {
        [layer removeFromSuperlayer];
    }
    markings = nil;

    pipLayer = [CAShapeLayer layer];
    pipLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.1) radius:self.bounds.size.width*0.03 startAngle:0.0 endAngle:2.0*M_PI clockwise:NO].CGPath;
    pipLayer.frame = self.frame;
    pipLayer.opaque = NO;
    pipLayer.backgroundColor = [UIColor clearColor].CGColor;

    [shapeLayer addSublayer:pipLayer];

    return shapeLayer;
}

- (CAShapeLayer*)createKnobWithMarkings
{
    shapeLayer = [CAShapeLayer layer];
    shapeLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5) radius:self.bounds.size.width*0.45 startAngle:0.0 endAngle:2.0*M_PI clockwise:NO].CGPath;
    shapeLayer.frame = self.frame;
    shapeLayer.backgroundColor = [UIColor clearColor].CGColor;
    shapeLayer.opaque = NO;

    [pipLayer removeFromSuperlayer];
    pipLayer = nil;
    [self addMarkings];

    return shapeLayer;
}

- (CAShapeLayer*)createRotaryDial
{
    UIBezierPath* path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5) radius:self.bounds.size.width*0.5 startAngle:0.0 endAngle:2.0*M_PI clockwise:NO];

    int j;
    for (j=0; j<10; ++j)
    {
        double centerAngle = M_PI_4 + j*M_PI/6.0;
        double centerX = self.bounds.size.width*0.5 + 105.0 * cos(centerAngle);
        double centerY = self.bounds.size.height*0.5 - 105.0 * sin(centerAngle);
        [path addArcWithCenter:CGPointMake(centerX, centerY) radius:22.0 startAngle:M_PI_2-centerAngle endAngle:1.5*M_PI-centerAngle clockwise:YES];
    }
    for (--j; j>=0; --j)
    {
        double centerAngle = M_PI_4 + j*M_PI/6.0;
        double centerX = self.bounds.size.width*0.5 + 105.0 * cos(centerAngle);
        double centerY = self.bounds.size.height*0.5 - 105.0 * sin(centerAngle);
        [path addArcWithCenter:CGPointMake(centerX, centerY) radius:22.0 startAngle:1.5*M_PI-centerAngle endAngle:M_PI_2-centerAngle clockwise:YES];
    }

    shapeLayer = [CAShapeLayer layer];
    shapeLayer.path = path.CGPath;
    shapeLayer.frame = self.frame;
    shapeLayer.backgroundColor = [UIColor clearColor].CGColor;
    shapeLayer.opaque = NO;

    return shapeLayer;
}

- (CALayer*)createDialNumbers
{
    backgroundLayer.contents = nil;
    for (CALayer* layer in dialMarkings)
    {
        [layer removeFromSuperlayer];
    }
    dialMarkings = [NSMutableArray array];

    CGFloat fontSize = self.fontSizeForTitles;
    int j;
    for (j=0; j<10; ++j)
    {
        double centerAngle = M_PI_4 + j*M_PI/6.0;
        double centerX = self.bounds.size.width*0.5 + 105.0 * cos(centerAngle);
        double centerY = self.bounds.size.height*0.5 - 105.0 * sin(centerAngle);

        CATextLayer* textLayer = [CATextLayer layer];
        textLayer.string = [NSString stringWithFormat:@"%d", (j+1)%10];
        textLayer.alignmentMode = kCAAlignmentCenter;
        textLayer.fontSize = fontSize;
        textLayer.backgroundColor = [UIColor clearColor].CGColor;
        textLayer.opaque = NO;

        CGSize textSize = [textLayer.string sizeOfTextWithFontSize:textLayer.fontSize];
        textLayer.frame = CGRectMake(centerX-textSize.width*0.5, centerY-textSize.height*0.5, textSize.width, textSize.height);

        [dialMarkings addObject:textLayer];
        [backgroundLayer addSublayer:textLayer];
    }

    return backgroundLayer;
}

- (CGFloat)titleCircumferenceWithFontSize:(CGFloat)fontSize
{
    CGFloat circumference = 0.0;
    for (NSString* title in _titles) {
        CGSize textSize = [title sizeOfTextWithFontSize:fontSize];
        circumference += textSize.width;
    }

    return circumference;
}

- (CGFloat)fontSizeForTitles
{
    CGFloat fontSize;
    CGFloat fontSizes[] = { /* 36.0, */ 24.0, 18.0, 14.0, 12.0, 10.0 };

    double angle = _circular ? 2.0*M_PI : _max - _min;

    int index;
    for (index=0; index<sizeof(fontSizes)/sizeof(CGFloat); ++index) {
        fontSize = fontSizes[index];
        CGFloat circumference = [self titleCircumferenceWithFontSize:fontSize];

        // Empirically, this 0.25 works out well. This allows for a little padding between text segments.
        if (circumference <= angle*self.bounds.size.width*0.25) break;
    }

    return fontSize;
}

@end
