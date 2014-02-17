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
typedef NS_ENUM(NSInteger, IKCMode) {
    IKCMLinearReturn,   ///< Like a circular generalization of the picker view control. The knob turns continuously, but it can only come to rest at certain allowed positions. After being released, it animates to an allowed position at a fixed rate.
    IKCMWheelOfFortune, ///< Like a carnival wheel. Knob can stop at any position in a segment with the exception of narrow strips between them. If it lands very near the boundary between segments, it animates to the closest side.
    IKCMContinuous,     ///< Like a circular generalization of the slider control.
    IKCMRotaryDial      ///< TODO: Like an old-school telephone dial. (Currently unimplemented.)
};

@interface IOSKnobControl : UIControl

#pragma mark - Properties

/**
 * Specifies which mode to use for this knob control. IKCMDiscrete is the default.
 */
@property (nonatomic) IKCMode mode;

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
@property (nonatomic) float timeScale;

/**
 * Current position index in discrete mode. Which of the positions is selected? This is simply (position-min)/(max-min)*positions. If circular is YES, the min and max
 * properties are ignored, and then positionIndex is position/2/M_PI*positions.
 * This property always returns a non-negative number. While position may return a negative angle, positionIndex will range from
 * 0 to positions-1. For example, if positions is 6, positionIndex 0 will range from position -M_PI/6 to M_PI/6. The region from
 * -M_PI/2 to -M_PI/6 will have positionIndex 5 instead of -1.
 * DEBT: Should this have a setter? Should I be able to set a discrete knob to position 3, e.g., rather than having to do it by setting the position property?
 */
@property (readonly, nonatomic) int positionIndex;

#pragma mark - Object Lifecycle

/**
 * Inherited from UIView and UIControl. No image is yet specified. Must subsequently call at least
 * setImage:forState: for the UIControlStateNormal state.
 * @param frame the initial frame for the control
 */
- (id)initWithFrame:(CGRect)frame;

/**
 * Initialize the control with a specific knob image for the UIControlStateNormal state.
 * @param frame the initial frame for the control
 * @param image an image to use for the control's normal state
 */
- (id)initWithFrame:(CGRect)frame image:(UIImage*)image;

/**
 * Initialize the control with a specific knob image for the UIControlStateNormal state. 
 * The image used will be [UIImage imageNamed:imageSetName]. The image will be selected appropriately for the screen density
 * from the specified image set in the application's asset catalog named @a imageSetName.
 * @param frame the initial frame for the control
 * @param imageSetName the name of an image set in the application's asset catalog
 */
- (id)initWithFrame:(CGRect)frame imageNamed:(NSString*)imageSetName;

#pragma mark - Public Methods

/**
 * Set the position property of the control with or without animation.
 * @param position the new angular position for the knob; will be adjusted to lie within (-M_PI,M_PI]
 * @param animated if YES, animate the transition to the new position; otherwise, the transition is instantaneous
 */
- (void)setPosition:(float)position animated:(BOOL)animated;

// The following copied and pasted from UIButton. For each possible control state, optionally specify an image.

/**
 * Retrieve the image to use for a particular control state. The @a state argument may be any bitwise combination
 * of UIControlState values, e.g. UIControlStateHighlighted|UIConrolStateDisabled. The image for the
 * higher-valued state is returned. For example, in the previous case, since UIControlStateDisabled > UIControlStateHighlighted,
 * the disabled image will be returned. If no image has been configured for the specified state (e.g., in this example,
 * if there were no disabled image specified), returns the image for UIControlStateNormal, if any has been set.
 * If any of the UIControlStateApplication bits is set, returns the image for UIControlStateNormal.
 * @param state any valid control state
 * @return the image to use for the specified state
 */
- (UIImage *)imageForState:(UIControlState)state;

/**
 * Set the image to use for a specific control state. Unlike the case with imageForState:, the @a state parameter
 * must be one of UIControlStateNormal, UIControlStateHighlighted, UIControlStateDisabled or UIControlStateSelected.
 * Mixed states like UIControlStateHighlighted|UIControlStateDisabled will be ignored, and no image values will be
 * modified.
 * @param image the image to use for the specified state
 * @param state one of UIControlStateNormal, UIcontrolStateHighlighted, UIControlStateDisabled or UIControlStateSelected
 */
- (void)setImage:(UIImage *)image forState:(UIControlState)state;

@end
