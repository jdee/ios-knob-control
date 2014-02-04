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
    UIImage* _image;
}
- (void)handlePan:(UIPanGestureRecognizer*)sender;
@end

@implementation IOSKnobControl

@dynamic positionIndex, image;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        /*
         * If this constructor is used, the image property is nil and must be
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
        self.image = image;
        [self setDefaults];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame imageNamed:(NSString *)filename
{
    self = [super initWithFrame:frame];
    if (self) {
        self.image = [UIImage imageNamed:filename];
        [self setDefaults];
    }
    return self;
}

- (void)setDefaults
{
    self.mode = IKCMDiscrete;
    self.animation = IKCASlowReturn;
    self.circular = YES;
    self.position = 0.0;
    self.min = 0.0;
    self.max = 2.0*M_PI;
    self.positions = 2;
    self.angularMomentum = NO;
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;
    self.clockwise = NO;

    panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:panGestureRecognizer];
}

- (UIImage *)image
{
    return _image;
}

- (void)setImage:(UIImage *)image
{
    _image = image;

    if (!imageLayer) {
        imageLayer = [CALayer layer];
        imageLayer.frame = self.frame;
        imageLayer.backgroundColor = [UIColor clearColor].CGColor;
        imageLayer.opaque = NO;
        [self.layer addSublayer:imageLayer];
    }

    imageLayer.contents = (id)image.CGImage;
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
            if (self.mode == IKCMDiscrete) {
                [self snapToNearestPosition];
            }

            break;
        default:
            /* keep it in [0, 2*M_PI) */
            while (position >= 2.0*M_PI) position -= 2.0*M_PI;
            while (position < 0.0) position += 2.0*M_PI;

            if (!self.circular) {
                // for this, convert to within (-pi, pi]
                float converted = position;
                if (converted > M_PI) converted -= 2.0*M_PI;
                if (converted < self.min) converted = self.min;
                if (converted > self.max) converted = self.max;
                
                position = converted;
                if (position < 0.0) position += 2.0*M_PI;
            }

            self.position = position;

            // while the gesture is in progress, just track the touch
            imageLayer.transform = CATransform3DMakeRotation(self.clockwise ? position : -position, 0, 0, 1);

            [self sendActionsForControlEvents:UIControlEventValueChanged];
            break;
    }
}

- (void)snapToNearestPosition
{
    /*
     * Animate return to nearest position
     */
    double nearestPositionAngle = self.positionIndex*M_PI*2.0/self.positions;
    double delta = nearestPositionAngle - self.position;

    while (delta > M_PI) {
        nearestPositionAngle -= 2.0*M_PI;
        delta -= 2.0*M_PI;
    }
    while (delta <= -M_PI) {
        nearestPositionAngle += 2.0*M_PI;
        delta += 2.0*M_PI;
    }

    const float threshold = 0.9*M_PI/self.positions;

    switch (self.animation) {
        case IKCAWheelOfFortune:
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

    // The largest absolute value of delta is M_PI/self.positions, halfway between segments.
    // If delta is M_PI/self.positions, the duration is maximal. Otherwise, it scales linearly.
    // Without this adjustment, the animation will seem much faster for large
    // deltas.

    // TODO: Make this constant a property.
    double duration = 1.0*fabs(delta*self.positions/M_PI);
    float actual = self.clockwise ? nearestPositionAngle : -nearestPositionAngle;

    [CATransaction new];
    [CATransaction setDisableActions:YES];
    imageLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);

    // Provide an animation
    // Key-frame animation to ensure rotates in correct direction
    CGFloat midAngle = 0.5*(actual+self.position);
    CAKeyframeAnimation *animation = [CAKeyframeAnimation
                                      animationWithKeyPath:@"transform.rotation.z"];
    animation.values = @[@(self.position), @(midAngle), @(actual)];

    switch (self.animation) {
        case IKCAWheelOfFortune:
        case IKCASlowReturn:
            animation.keyTimes = @[@(0.0), @(0.5), @(1.0)];
            animation.duration = duration;
            animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
            break;
        case IKCARotarySwitch:
            break;
    }

    [imageLayer addAnimation:animation forKey:nil];

    [CATransaction commit];

    // DEBT: This ought to change over time with the animation, rather than instantaneously
    // like this. Though at least the value changed event should probably only fire once, after
    // the animation has completed. And maybe the position could be assigned then too.
    while (nearestPositionAngle >= 2.0*M_PI) nearestPositionAngle -= 2.0*M_PI;
    self.position = nearestPositionAngle;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

@end
