//
//  IOSKnobControl.m
//  Laertes
//
//  Created by Jimmy Dee on 1/29/14.
//  Copyright (c) 2014 Jimmy Dee. All rights reserved.
//

#import "IOSKnobControl.h"

@interface IOSKnobControl() {
    float touchStart, positionStart;
    UIPanGestureRecognizer* panGestureRecognizer;
    CALayer* imageLayer;
    UIImage* images[4];
}
- (void)handlePan:(UIPanGestureRecognizer*)sender;
- (void)returnToPosition:(float)position duration:(float)duration;

/*
 * Returns the nearest allowed position
 */
@property (readonly) float nearestPosition;
@end

@implementation IOSKnobControl

@dynamic positionIndex, nearestPosition;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        /*
         * If this constructor is used, the image property is initialized to nil and must be
         * set manually.
         */
        [self setDefaults];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame image:(UIImage *)image
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setImage:image forState:UIControlStateNormal];
        [self setDefaults];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame imageNamed:(NSString *)filename
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImage* image = [UIImage imageNamed:filename];
        [self setImage:image forState:UIControlStateNormal];
        [self setDefaults];
    }
    return self;
}

- (void)setDefaults
{
    _mode = IKCMLinearReturn;
    _clockwise = NO;
    _position = 0.0;
    _circular = YES;
    _min = -M_PI;
    _max = M_PI;
    _positions = 2;
    _angularMomentum = NO;
    _scale = 1.0;
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;

    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panGestureRecognizer.enabled = self.enabled;
    [self addGestureRecognizer:panGestureRecognizer];

    [self updateImage];
}

- (UIImage *)imageForState:(UIControlState)state
{
    int index = [self indexForState:state];
    /*
     * Like UIButton, use the image for UIControlStateNormal if none present.
     */
    return index >= 0 && images[index] ? images[index] : images[[self indexForState:UIControlStateNormal]];
}

- (void)setImage:(UIImage *)image forState:(UIControlState)state
{
    int index = [self indexForState:state];
    /*
     * Don't accept mixed states here. Cannot pass, e.g., UIControlStateHighlighted & UIControlStateDisabled.
     * Those values are ignored here.
     * DEBT: Add this to the doc for the method.
     */
    if (state == UIControlStateNormal || state == UIControlStateHighlighted || state == UIControlStateDisabled || state == UIControlStateSelected) {
        images[index] = image;
        if (state == self.state) {
            [self updateImage];
        }
    }
}

/*
 * Private method used by imageForState: and setImage:forState:.
 * For a pure state (only one bit set) other than normal, returns that bit + 1. If no
 * bits set, returns 0. If more than one bit set, returns the
 * index corresponding to the highest bit. So for state == UIControlStateNormal,
 * returns 0. For state == UIControlStateDisabled, returns 2. For
 * state == UIControlStateDisabled & UIControlStateSelected, returns 3.
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
    if (!imageLayer) {
        imageLayer = [CALayer layer];
        imageLayer.frame = self.frame;
        imageLayer.backgroundColor = [UIColor clearColor].CGColor;
        imageLayer.opaque = NO;
        [self.layer addSublayer:imageLayer];
    }

    imageLayer.contents = (id)[self imageForState:self.state].CGImage;
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    panGestureRecognizer.enabled = enabled;

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

- (void)setPosition:(float)position
{
    [self setPosition:position animated:NO];
}

- (void)setPosition:(float)position animated:(BOOL)animated
{
    if (_circular == NO) {
        // enforce min and max
        if (position < _min) position = _min;
        if (position > _max) position = _max;
    }

    float delta = fabs(position - _position);
    // DEBT: Make these constants macros, properties, something.
    [self returnToPosition:position duration:animated ? delta*0.5/M_PI : 0.0];
}

- (int)positionIndex
{
    if (self.mode == IKCMContinuous) return -1;

    int index = self.circular ? self.position*0.5/M_PI*self.positions+0.5 : (self.position-self.min)/(self.max-self.min)*self.positions+0.5;

    // basically just handle the last half segment before 2*M_PI
    while (index >= self.positions) index -= self.positions;

    return index;
}

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

// DEBT: Factor this stuff into a separate GR?
- (void)handlePan:(UIPanGestureRecognizer *)sender
{
    // most recent position of touch in center frame of control
    CGPoint centerFrameLocation = [self transformLocationToCenterFrame:[sender locationInView:self]];
    CGPoint centerFrameTranslation = [self transformTranslationToCenterFrame:[sender translationInView:self]];
    centerFrameLocation.x += centerFrameTranslation.x;
    centerFrameLocation.y += centerFrameTranslation.y;
    float touch = [self polarAngleOfPoint:centerFrameLocation];

    if (sender.state == UIGestureRecognizerStateBegan) {
        touchStart = touch;
        positionStart = self.position;
    }

    float position = positionStart + touch - touchStart;

#if 0
    NSLog(@"knob turned. state = %s, touchStart = %f, positionStart = %f, touch = %f, position = %f",
          (sender.state == UIGestureRecognizerStateBegan ? "began" :
           sender.state == UIGestureRecognizerStateChanged ? "changed" :
           sender.state == UIGestureRecognizerStateEnded ? "ended" : "<misc>"), touchStart, positionStart, touch, position);
#endif

    switch (sender.state) {
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
            if (self.mode == IKCMLinearReturn || self.mode == IKCMWheelOfFortune) {
                [self snapToNearestPosition];
            }
            self.highlighted = NO;

            break;
        default:
            /* keep it in (-M_PI, M_PI] */
            while (position > M_PI) position -= 2.0*M_PI;
            while (position <= -M_PI) position += 2.0*M_PI;

            if (!self.circular) {
                if (position < self.min) position = self.min;
                if (position > self.max) position = self.max;
            }

            self.position = position;

            // while the gesture is in progress, just track the touch
            imageLayer.transform = CATransform3DMakeRotation(self.clockwise ? position : -position, 0, 0, 1);

            self.highlighted = YES;

            [self sendActionsForControlEvents:UIControlEventValueChanged];
            break;
    }
}

/*
 * DEBT: This works correctly when circular is YES. Otherwise, the min and max
 * need to be considered. You could have a situation, e.g., with min = - M_PI and
 * max = M_PI, where the nearest position could be across the min/max boundary.
 * In that case, we should just ignore the snap and return to the original position
 * when released.
 */
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

            // DEBT: Make this constant a property or #define something
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

    float duration = _scale*fabs(delta*self.positions/M_PI);
    [self returnToPosition:nearestPositionAngle duration:duration];
}

- (float)nearestPosition
{
    return self.positionIndex*M_PI*2.0/self.positions;
}

- (void)returnToPosition:(float)position duration:(float)duration
{
    float actual = self.clockwise ? position : -position;

    if (duration > 0.0) {
        // The largest absolute value of delta is M_PI/self.positions, halfway between segments.
        // If delta is M_PI/self.positions, the duration is maximal. Otherwise, it scales linearly.
        // Without this adjustment, the animation will seem much faster for large
        // deltas.

        [CATransaction new];
        [CATransaction setDisableActions:YES];
        imageLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);

        // Provide an animation
        // Key-frame animation to ensure rotates in correct direction
        CGFloat midAngle = 0.5*(actual+self.position);
        CAKeyframeAnimation *animation = [CAKeyframeAnimation
                                          animationWithKeyPath:@"transform.rotation.z"];
        animation.values = @[@(self.position), @(midAngle), @(actual)];

        switch (self.mode) {
            case IKCMWheelOfFortune:
            case IKCMLinearReturn:
                animation.keyTimes = @[@(0.0), @(0.5), @(1.0)];
                animation.duration = duration;
                animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
                break;
            default:
                break;
        }
        
        [imageLayer addAnimation:animation forKey:nil];
        
        [CATransaction commit];
    }
    else {
        imageLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);
    }

    // DEBT: This ought to change over time with the animation, rather than instantaneously
    // like this. Though at least the value changed event should probably only fire once, after
    // the animation has completed. And maybe the position could be assigned then too.
    while (position >= 2.0*M_PI) position -= 2.0*M_PI;
    _position = position;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
