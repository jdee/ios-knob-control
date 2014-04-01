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
#define IKC_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE 0.52359878163217 // M_PI/6.0
#define IKC_EPSILON 1e-7

// Must match IKC_VERSION and IKC_BUILD from IOSKnobControl.h.
#define IKC_TARGET_VERSION 0x010100
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

@interface IOSKnobControl()
/*
 * Returns the nearest allowed position
 */
@property (readonly) float nearestPosition;
@property (readonly) UIImage* imageForCurrentState;
@end

@implementation IOSKnobControl {
    float touchStart, positionStart, currentTouch;
    UIGestureRecognizer* gestureRecognizer;
    CALayer* imageLayer;
    CAShapeLayer* shapeLayer, *pipLayer;
    NSMutableArray* markings;
    UIImage* images[4];
    BOOL rotating;
}

@dynamic positionIndex, nearestPosition, imageForCurrentState;

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

- (void)setPositions:(int)positions
{
    _positions = positions;
    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self.layer addSublayer:imageLayer];
}

- (void)setTitles:(NSArray *)titles
{
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
}

- (void)setClockwise:(BOOL)clockwise
{
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

- (int)positionIndex
{
    if (self.mode == IKCMContinuous) return -1;

    float converted = self.position;
    if (converted < 0) converted += 2.0*M_PI;

    int index = self.circular ? converted*0.5/M_PI*self.positions+0.5 : (self.position-self.min)/(self.max-self.min)*self.positions+0.5;

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
}

- (void)setMax:(float)max
{
    max = normalizePosition(max);
    if (max < 0.0) max = 0.0;
    if (max >= M_PI) max = M_PI - IKC_EPSILON;
    _max = max;
}

- (void)setGesture:(IKCGesture)gesture
{
    _gesture = gesture;
    [self setupGestureRecognizer];
}

- (void)tintColorDidChange
{
    if ([imageLayer isKindOfClass:CAShapeLayer.class]) {
        [self updateShapeLayer];
    }
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
    float range = self.circular ? 2.0*M_PI : self.max - self.min;
    float position = self.positionIndex*range/self.positions;
    if (2*self.positionIndex == self.positions && self.circular == YES) {
        /*
         * Try to keep things confined to (-M_PI,M_PI] and avoid a return to -M_PI.
         * This only happens when circular is YES.
         * https://github.com/jdee/ios-knob-control/issues/7
         */
        return M_PI - IKC_EPSILON;
    }
    return position;
}

#pragma mark - Private Methods: Animation

- (void)snapToNearestPosition
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

    float duration = _timeScale/IKC_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE*fabs(delta);
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
    [self sendActionsForControlEvents:UIControlEventValueChanged];
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

#if 0
    NSLog(@"knob turned. state = %s, touchStart = %f, positionStart = %f, touch = %f, position = %f",
          (sender.state == UIGestureRecognizerStateBegan ? "began" :
           sender.state == UIGestureRecognizerStateChanged ? "changed" :
           sender.state == UIGestureRecognizerStateEnded ? "ended" : "<misc>"), touchStart, positionStart, touch, position);
#endif

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

- (void)followGesture:(UIGestureRecognizer*)sender toPosition:(double)position
{
    switch (sender.state) {
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
            if (self.mode == IKCMLinearReturn || self.mode == IKCMWheelOfFortune) {
                [self snapToNearestPosition];
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

- (UIImage*)imageForCurrentState
{
    return [self imageForState:self.state];
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
    UIImage* image = self.imageForCurrentState;
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
    UIColor* highlightColor, *normalColor, *disabledColor, *markingColor, *disabledMarkingColor;

    float red, green, blue, alpha;
    [self.tintColor getRed:&red green:&green blue:&blue alpha:&alpha];

    float hue, saturation, brightness;
    [self.tintColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

    if ((red == green && green == blue) || brightness < 0.02) {
        /*
         * This is for any shade of gray from black to white. Unfortunately, black is not really black.
         * It comes out as a red hue. Hence the brightness test above.
         */
        highlightColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:alpha];
        normalColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:alpha];
        disabledColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:alpha];

        markingColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:alpha];
        disabledMarkingColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:alpha];
    }
    else {
        highlightColor = [UIColor colorWithHue:hue saturation:0.7 brightness:1.0 alpha:alpha];
        normalColor = [UIColor colorWithHue:hue saturation:1.0 brightness:0.9 alpha:alpha];
        disabledColor = [UIColor colorWithHue:hue saturation:0.2 brightness:0.9 alpha:alpha];

        markingColor = [UIColor colorWithHue:hue saturation:1.0 brightness:0.5 alpha:alpha];
        disabledMarkingColor = [UIColor colorWithHue:hue saturation:0.2 brightness:0.5 alpha:alpha];
    }

    shapeLayer.fillColor = (self.state & UIControlStateHighlighted) ? highlightColor.CGColor :
        (self.state & UIControlStateDisabled) ? disabledColor.CGColor :
        normalColor.CGColor;
    pipLayer.fillColor = (self.state & UIControlStateDisabled) ? disabledMarkingColor.CGColor : markingColor.CGColor;

    for (CATextLayer* layer in markings) {
        // layer.foregroundColor = (self.state & UIControlStateDisabled) ? disabledMarkingColor.CGColor : markingColor.CGColor;
        layer.foregroundColor = (self.state & UIControlStateDisabled) ? disabledMarkingColor.CGColor : markingColor.CGColor;
    }
}

- (void)addMarkings
{
    markings = [NSMutableArray array];
    for (CATextLayer* layer in markings) {
        [layer removeFromSuperlayer];
    }

    int j=0;
    for (j=0; j<_positions; ++j) {
        NSString* title;
        if (j < _titles.count) title = [_titles objectAtIndex:j];

        if (!title) {
            title = [NSString stringWithFormat:@"%d", j];
        }

        CATextLayer* layer = [CATextLayer layer];
        layer.string = title;
        layer.fontSize = 18.0;
        layer.alignmentMode = kCAAlignmentCenter;

        UIFont* font = ((__bridge UIFont*)layer.font).copy;

        NSMutableDictionary* attrs = [NSMutableDictionary dictionary];
        [attrs setObject:font forKey:NSFontAttributeName];

        CGSize size = [layer.string sizeWithAttributes:attrs];

        float angle = (2.0*M_PI/_positions)*j;
        float actual = self.clockwise ? -angle : angle;

        layer.frame = CGRectMake(0.5*self.bounds.size.width*(1+0.7*sin(actual))-0.5*size.width, 0.5*self.bounds.size.height*(1-0.7*cos(actual))-0.5*size.height, size.width, size.height);
        layer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);

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
        shapeLayer = [CAShapeLayer layer];
        shapeLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5) radius:self.bounds.size.width*0.45 startAngle:0.0 endAngle:2.0*M_PI clockwise:NO].CGPath;
        shapeLayer.frame = self.frame;
        shapeLayer.backgroundColor = [UIColor clearColor].CGColor;
        shapeLayer.opaque = NO;

        if (self.mode == IKCMLinearReturn || self.mode == IKCMWheelOfFortune) {
            [pipLayer removeFromSuperlayer];
            pipLayer = nil;
            [self addMarkings];
        }
        else {
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
        }

        float actual = self.clockwise ? self.position : -self.position;
        shapeLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);
    }

    return shapeLayer;
}

@end
