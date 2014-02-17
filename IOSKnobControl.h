//
//  IOSKnobControl.h
//  Laertes
//
//  Created by Jimmy Dee on 1/29/14.
//  Copyright (c) 2014 Jimmy Dee. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * The knob control is like a circular generalization of either a picker view or a slider control.
 * In both cases, the circle may or may not be closed.
 */
enum IKCMode {
    IKCMLinearReturn,   ///< Like a circular generalization of the picker view control. The knob turns continuously, but it can only come to rest at certain allowed positions. After being released, it animates to an allowed position at a fixed rate.
    IKCMWheelOfFortune, ///<
    IKCMContinuous,     ///< Like a circular generalization of the slider control.
    IKCMRotaryDial      ///< TODO: Like an old-school telephone dial.
};

@interface IOSKnobControl : UIControl

/**
 * Specifies which mode to use for this knob control. IKCMDiscrete is the default.
 */
@property (nonatomic) enum IKCMode mode;

/**
 * TODO: (Currently only NO supported.)
 *
 * Specifies whether the knob continues to rotate after the user releases it. This applies both to discrete
 * and continuous modes. It can apply whether circular is YES or NO. If circular is NO, and angularMomentum is
 * YES, the control will usually continue animating to the min or max when released.
 *
 * The default is NO.
 */
@property (nonatomic) BOOL angularMomentum;

/**
 * If this property is set to YES, the circle is closed. That is, all angular positions in [0,2*M_PI) are allowed, and 0 is identified with 2*M_PI, so it is possible to
 * continue around the circle. The min and max properties of the control are ignored.
 * If this property is set to NO, the circle is open, and the min and max properties are consulted. These may take any values in radians. Note that if min + 2*M_PI == max,
 * then all positions in [min, min+2*M_PI) are allowed, but it is not possible to continue around the circle below min or above max. It is assumed that 0.0, the initial value,
 * is allowed, so min must be within [-M_PI,0] and max must be within [0,M_PI].
 * TODO: Validate/enforce the ranges of min and max.
 *
 * The default value of this property is YES.
 */
@property (nonatomic) BOOL circular;

/**
 * Specifies whether the value of position increases when the knob is turned clockwise instead of counterclockwise.
 * The default value of this property is NO.
 */
@property (nonatomic) BOOL clockwise;

/**
 * Minimum value of the position property if circular == NO. Default is -M_PI.
 */
@property (nonatomic) float min;

/**
 * Maximum value of the position property if circular == NO. Default is M_PI.
 */
@property (nonatomic) float max;

/**
 * Number of discrete positions. Default and minimum are 2. No maximum. (DEBT: Should there be some practical max?) Not consulted in continuous mode.
 */
@property (nonatomic) int positions;

/**
 * Current angular position, in radians, of the knob. Initial value is 0.
 */
@property (nonatomic) float position;

/**
 * Used by the linear return mode to specify the time scale for the animation.
 * Default is 1.0. The duration of the animation is proportional to this property.
 * Set the number below 1.0 to speed up the animation, and above to slow it down.
 */
@property (nonatomic) float scale;

/**
 * Current position index in discrete mode. Which of the positions is selected? This is simply (position-min)/(max-min)*positions. If circular is YES, the min and max
 * properties are ignored, and then positionIndex is position/2/M_PI*positions.
 * This property always returns a non-negative number. While position may return a negative angle, positionIndex will range from
 * 0 to positions-1. For example, if positions is 6, positionIndex 0 will range from position -M_PI/6 to M_PI/6. The region from
 * -M_PI/2 to -M_PI/6 will have positionIndex 5 instead of -1.
 * DEBT: Should this have a setter? Should I be able to set a discrete knob to position 3, e.g., rather than having to do it by setting the position property?
 */
@property (readonly, nonatomic) int positionIndex;

/**
 * Inherited from UIView and UIControl. This constructor results in a nil image property.
 * The image property must be manually set with a call to the setImage method.
 */
- (id)initWithFrame:(CGRect)frame;

/**
 * Initialize the control with a specific knob image. The image argument here is the initial value of the image
 * property of the control object. That property may be changed later.
 */
- (id)initWithFrame:(CGRect)frame image:(UIImage*)image;

/**
 * Initialize the control with a specific knob image. The initial value of the image property of the knob
 * control will be [UIImage imageNamed:filename]. The specified filename must be an image in the application
 * bundle.
 */
- (id)initWithFrame:(CGRect)frame imageNamed:(NSString*)filename;

/**
 * Set the position property of the control with or without animation.
 */
- (void)setPosition:(float)position animated:(BOOL)animated;

/**
 * Copied and pasted from UIButton. For each possible control state, optionally
 * specify an image.
 */
- (UIImage *)imageForState:(UIControlState)state;
- (void)setImage:(UIImage *)image forState:(UIControlState)state;

@end
