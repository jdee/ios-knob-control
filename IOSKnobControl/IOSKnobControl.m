//
//  IOSKnobControl.m
//  Laertes
//
//  Created by Jimmy Dee on 1/29/14.
//  Copyright (c) 2014 Jimmy Dee. All rights reserved.
//

#import "IOSKnobControl.h"

@interface IOSKnobControl() {
    CGPoint rotationStart;
    UIPanGestureRecognizer* panGestureRecognizer;
    CALayer* imageLayer;
    UIImage* _image;
}
- (void)handlePan:(UIPanGestureRecognizer*)sender;
@end

@implementation IOSKnobControl

@dynamic positionIndex, image;

// returns a number in [0, 2*M_PI)
+ (double)polarAngleOfPoint:(CGPoint)point
{
    return atan2(point.y, point.x);
}

+ (double)rotationFromPoint:(CGPoint)origin withTranslation:(CGPoint)translation
{
    CGPoint destination;
    destination.x = origin.x + translation.x;
    destination.y = origin.y + translation.y;

    return [self polarAngleOfPoint:destination] - [self polarAngleOfPoint:origin];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
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

        panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:panGestureRecognizer];
    }
    return self;
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

// DEBT: Factor this stuff into a separate GR
- (void)handlePan:(UIPanGestureRecognizer *)sender
{
    // NSLog(@"wheel rotated");
    CGPoint translation = [sender translationInView:self];
    CGPoint centerFrameTranslation = [self transformTranslationToCenterFrame:translation];

    // DEBT: Should rotationStart always just be adjusted to [self transformLocationToCenterFrame:[touch locationInView:self]]?
    double rotation = [self.class rotationFromPoint:rotationStart withTranslation:centerFrameTranslation];
    rotationStart.x += centerFrameTranslation.x;
    rotationStart.y += centerFrameTranslation.y;

    // must be at least 100 pts from the center
    if (rotationStart.x*rotationStart.x + rotationStart.y*rotationStart.y < 1.0e4) return;

    float position = self.position;

    position -= rotation;
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
    imageLayer.transform = CATransform3DMakeRotation(position, 0, 0, 1);

    [self sendActionsForControlEvents:UIControlEventValueChanged];

    switch (sender.state) {
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:

            if (self.mode == IKCMDiscrete) {
                [self snapToNearestPosition];
            }

            break;
        default:
            break;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    switch (touch.phase) {
        case UITouchPhaseBegan:
            rotationStart = [self transformLocationToCenterFrame:[touch locationInView:self]];
            break;
        default:
            break;
    }

    return YES;
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

    switch (self.animation) {
        case IKCAWheelOfFortune:
            // Exclude the outer 10% of each segment. Otherwise, like continuous mode.
            // If it has to be returned to the interior of the segment, the animation
            // is the same as the slow return animation, but it returns to the nearest
            // edge of the segment interior, not the center of the segment.

            // DEBT: Make this constant a property or something
            if (delta*self.positions/M_PI > 0.9) {
                delta = self.positions/M_PI*0.9;
                nearestPositionAngle = self.position + delta;
            }
            else if (delta*self.positions/M_PI < -0.9) {
                delta = -self.positions/M_PI*0.9;
                nearestPositionAngle = self.position + delta;
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
    double duration = 0.15*fabs(delta*self.positions/M_PI);

    [CATransaction new];
    [CATransaction setDisableActions:YES];
    imageLayer.transform = CATransform3DMakeRotation(nearestPositionAngle, 0, 0, 1);

    // Provide an animation
    // Key-frame animation to ensure rotates in correct direction
    CGFloat midAngle = 0.5*(nearestPositionAngle+self.position);
    CAKeyframeAnimation *animation = [CAKeyframeAnimation
                                      animationWithKeyPath:@"transform.rotation.z"];
    animation.values = @[@(self.position), @(midAngle), @(nearestPositionAngle)];

    switch (self.animation) {
        case IKCAWheelOfFortune:
        case IKCASlowReturn:
            animation.keyTimes = @[@(0), @(0.5), @(1.0)];
            animation.duration = duration;
            animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
            break;
        case IKCARotarySwitch:
            break;
            break;
    }

    [imageLayer addAnimation:animation forKey:nil];

    [CATransaction commit];
}

@end
