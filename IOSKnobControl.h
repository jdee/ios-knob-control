#import <UIKit/UIKit.h>

#if !__has_feature(objc_arc)
#error IOSKnobControl requires automatic reference counting.
#endif // objc_arc

#define IKC_VERSION_STRING @"1.3.0"
#define IKC_VERSION 0x010300
#define IKC_BUILD 1

/**
 * @mainpage iOS Knob Control
 *
 * https://github.com/jdee/ios-knob-control/
 *
 * A simple, reusable knob control. See the @ref IOSKnobControl class reference for details.
 *
 * Copyright (c) 2013-14, Jimmy Dee
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
 *     BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *     CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * The knob control is like a circular generalization of either a picker view or a slider control.
 * In both cases, the circle may or may not be closed.
 */
typedef NS_ENUM(NSInteger, IKCMode) {
    IKCModeLinearReturn,   ///< Like a circular generalization of the picker view control. The knob turns continuously, but it can only come to rest at certain allowed positions. After being released, it animates to an allowed position at a fixed rate.
    IKCModeWheelOfFortune, ///< Like a carnival wheel. Knob can stop at any position in a segment with the exception of narrow strips between them. If it lands very near the boundary between segments, it animates to the closest side.
    IKCModeContinuous,     ///< Like a circular generalization of the slider control.
    IKCModeRotaryDial      ///< Like an old rotary telephone dial.
};

typedef NS_ENUM(NSInteger, IKCGesture) {
    IKCGestureOneFingerRotation, ///< Custom gesture handling. One finger rotates the knob.
    IKCGestureTwoFingerRotation, ///< Uses the standard iOS two-finger rotation gesture. (Not available with IKCModeRotaryDial.)
    IKCGestureVerticalPan,       ///< Uses a vertical pan gesture. The image still rotates. (Not available with IKCModeRotaryDial.)
    IKCGestureTap                ///< Uses a tap gesture. The knob rotates to the position tapped. In rotary dial mode, rotates from the position tapped (dials that number).
};

#ifndef IKC_DISABLE_DEPRECATED
/*
 * For brevity, the individual enumerated values were previously named IKCMLinearReturn, etc. But the longer names provide for better interoperability with Swift.
 * By changing the enumeration names, these become IKCMode.LinearReturn, IKCMode.Continuous, etc., which can be used without the type qualification. These static constants
 * are provided for compatibility with the previous versions. If the static constants cause any linking problems, please use the new enumerations instead and
 * #define IKC_DISABLE_DEPRECATED. It's unlikely that this would happen in any circumstance, but it's most likely if you are compiling the control into a library.
 * If you simply drop the .h and .m into your app, there will be no issues.
 */

static const NSInteger IKCMLinearReturn DEPRECATED_MSG_ATTRIBUTE("Use IKCModeLinearReturn instead") = IKCModeLinearReturn;
static const NSInteger IKCMWheelOfFortune DEPRECATED_MSG_ATTRIBUTE("Use IKCModeWheelOfFortune instead") = IKCModeWheelOfFortune;
static const NSInteger IKCMContinuous DEPRECATED_MSG_ATTRIBUTE("Use IKCModeContinuous instead") = IKCModeContinuous;
static const NSInteger IKCMRotaryDial DEPRECATED_MSG_ATTRIBUTE("Use IKCModeRotaryDial instead") = IKCModeRotaryDial;

static const NSInteger IKCGOneFingerRotation DEPRECATED_MSG_ATTRIBUTE("Use IKCGestureOneFingerRotation instead") = IKCGestureOneFingerRotation;
static const NSInteger IKCGTwoFingerRotation DEPRECATED_MSG_ATTRIBUTE("Use IKCGestureTwoFingerRotation instead") = IKCGestureTwoFingerRotation;
static const NSInteger IKCGVerticalPan DEPRECATED_MSG_ATTRIBUTE("Use IKCGestureVerticalPan instead") = IKCGestureVerticalPan;
static const NSInteger IKCGTap DEPRECATED_MSG_ATTRIBUTE("Use IKCGestureTap instead") = IKCGestureTap;
#endif // IKC_DISABLE_DEPRECATED

/**
 * A simple, reusable rotary control. You may provide custom knob images or use the default images, which may be customized
 * using a number of properties and methods. The control chooses an image based on state,
 * like the UIButton control. In any state but disabled, the knob control responds to a one-fingered rotation gesture and
 * animates rotation of the current image in response, programmatically reading out the current angular position of the knob
 * and generating a UIControlEventValueChanged each time the knob rotates.
 *
 * The knob control and all images must be square. Images will usually be circles or regular polygons, with a
 * transparent background or a solid one that matches the view behind it. However, the aspect
 * ratio must be 1:1. The effect of the animation is circular rotation. This only works if the control
 * is square. You can produce other effects, for example, by partially clipping a square control
 * or using an oblong background. But the control itself always has to be square. If an oblong frame is specified
 * for the control, the frame will be made square. The larger of the original sides will will be used for both the
 * width and height. The origin of the frame will be unchanged.
 *
 * The knob control requires ARC, and hence iOS 5.0 or later. It has not been tested below iOS 6.1.
 */
@interface IOSKnobControl : UIControl

#pragma mark - Properties

/**
 * If set, the specified image is rendered in the background of the control. The default value is nil.
 *
 * If mode is IKCMRotaryDial, and backgroundImage is nil, the numbers on the dial will be rendered as the
 * background. Use this property to supply your own dial background instead of the generated one.
 */
@property (nonatomic) UIImage* backgroundImage;

/**
 * If this property is set to YES, the circle is closed. That is, all angular positions in (-M_PI,M_PI] are allowed, and -M_PI is identified with M_PI, so it is possible to
 * continue around the circle. The min and max properties of the control are ignored.
 *
 * If this property is set to NO, the circle is open, and the min and max properties are consulted.
 *
 * The default value of this property is YES. It is ignored in IKCModeRotaryDial.
 */
@property (nonatomic) BOOL circular;

/**
 * Specifies whether the value of position increases when the knob is turned clockwise instead of counterclockwise.
 * The default value of this property is NO. It is ignored in IKCModeRotaryDial.
 */
@property (nonatomic) BOOL clockwise;

/**
 * The fill color for the current state.
 */
@property (nonatomic, readonly) UIColor* currentFillColor;

/**
 * The image to use for the current state.
 */
@property (nonatomic, readonly) UIImage* currentImage;

/**
 * The title color to use for the current state.
 */
@property (nonatomic, readonly) UIColor* currentTitleColor;

/**
 * The font name to use when rendering text in the discrete modes, including rotary dial. Default is Helvetica. The font size is determined by the knob size and the number of positions.
 * CoreText interprets the font name and prefers PostScript names.
 */
@property (nonatomic) NSString* fontName;

/**
 * An image to render in the foreground. Like the background image, this is totally stationary. The knob image is sandwiched between them and is the only thing
 * that rotates. Obviously the foreground image has to be at least partly transparent. This is mainly useful for providing a stationary finger stop in the foreground of a
 * rotary dial, but it may be used with any mode.
 *
 * If mode is IKCModeRotaryDial, and foregroundImage is nil, a simple stop image is generated around 4:00 on the dial.
 */
@property (nonatomic) UIImage* foregroundImage;

/**
 * Specifies the gesture the control should recognize. The default is IKCGestureOneFingerRotation.
 */
@property (nonatomic) IKCGesture gesture;

/**
 * Maximum value of the position property if circular == NO. It is ignored in IKCModeRotaryDial. All values are valid, but min and max must be no more than 2*M_PI apart. The last one set wins.
 * For example, if you first set min to 0 and max to 3*M_PI, min will be adjusted to 2*M_PI after max is set. If you set max first and then min, max will be adjusted to M_PI after min is set. 
 * In all cases, if the current knob position is outside the allowed range, it will be made to lie within that range after the min or max is adjusted, by setting either to the min or max
 * value.
 */
@property (nonatomic) float max;

/**
 * Minimum value of the position property if circular == NO. It is ignored in IKCModeRotaryDial. All values are valid, but min and max must be no more than 2*M_PI apart. The last one set wins.
 * For example, if you first set min to 0 and max to 3*M_PI, min will be adjusted to 2*M_PI after max is set. If you set max first and then min, max will be adjusted to M_PI after min is set.
 * In all cases, if the current knob position is outside the allowed range, it will be made to lie within that range after the min or max is adjusted, by setting either to the min or max
 * value.
 */
@property (nonatomic) float min;

/**
 * Specifies which mode to use for this knob control. IKCModeLinearReturn is the default.
 */
@property (nonatomic) IKCMode mode;

/**
 * Only consulted if circular is YES. If YES, the position property will always be normalized to lie in (-M_PI,M_PI]. If NO, position can increase or decrease beyond those bounds, allowing
 * determination of the number of complete revolutions. If circular is NO, this property is ignored, and the min and max properties are consulted instead. Defaults to YES.
 */
@property (nonatomic) BOOL normalized;

/**
 * Current angular position, in radians, of the knob. Initial value is 0. Limited to (-M_PI,M_PI]. See @ref setPosition:animated: for more details,
 * including the role of the @ref circular, @ref min and @ref max properties. Assigning to this property results in a call to that method, with animated = NO.
 */
@property (nonatomic) float position;

/**
 * Current position index in discrete mode. Which of the positions is selected? This is simply (position-min)/(max-min)*positions. If circular is YES, the min and max
 * properties are ignored, and then positionIndex is position/2/M_PI*positions.
 * This property always returns a non-negative number. While position may return a negative angle, positionIndex will range from
 * 0 to positions-1. For example, if positions is 6 and circular is YES, positionIndex 0 will range from position -M_PI/6 to M_PI/6. The region from
 * -M_PI/2 to -M_PI/6 will have positionIndex 5 instead of -1.
 *
 * In IKCModeRotaryDial, this property is used to represent the number last dialed. This property should be consulted whenever a UIControlEventValueChanged is generated.
 */
@property (nonatomic) NSInteger positionIndex;

/**
 * Number of discrete positions. Default and minimum are 2. No maximum. (DEBT: Should there be some practical max?) Not consulted in continuous or rotary dial modes.
 */
@property (nonatomic) NSUInteger positions;

/**
 * Used to specify the time scale for return animations.
 * Default is 1.0. The duration of the animation is proportional to this property.
 * Set the number below 1.0 to speed up the animation, and above to slow it down.
 * Return animations will rotate through M_PI/6/timeScale radians per second or
 * through 2*M_PI in 12*timeScale s.
 */
@property (nonatomic) float timeScale;

/**
 * Only used when no image is provided in a discrete mode. These titles are rendered around the knob for each position index. If this property is nil (the default), the position
 * indices will be rendered instead (0, 1, 2, ...). If the length of titles is less than positions, remaining titles will be supplied by indices.
 */
@property (nonatomic) NSArray* titles;

#pragma mark - Object Lifecycle

/**
 * Inherited from UIView and UIControl. No image is yet specified. Must subsequently call at least
 * setImage:forState: for the UIControlStateNormal state.
 * @param frame the initial frame for the control
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Initialize the control with a specific knob image for the UIControlStateNormal state.
 * @param frame the initial frame for the control
 * @param image an image to use for the control's normal state
 */
- (instancetype)initWithFrame:(CGRect)frame image:(UIImage*)image;

/**
 * Initialize the control with a specific knob image for the UIControlStateNormal state. 
 * The image used will be [UIImage imageNamed:imageSetName]. The image will be selected appropriately for the screen density
 * from the specified image set in the application's asset catalog named @a imageSetName.
 * @param frame the initial frame for the control
 * @param imageSetName the name of an image set in the application's asset catalog
 */
- (instancetype)initWithFrame:(CGRect)frame imageNamed:(NSString*)imageSetName;

#pragma mark - Public Methods

/**
 * Set the @ref position property of the control with or without animation. The specified @a position will first be constrained to lie between min
 * and max if circular == NO. If the @a position is greater than max or less than min, it is adjusted to the closest of those values.
 * Next, the value of @a position is constrained to lie in (-M_PI,M_PI] by adding a (possibly zero or negative) integer multiple of 2*M_PI.
 * Finally, the @ref position property is set to this value. If @a animated is YES, the knob image gradually rotates to the new position;
 * otherwise the visual change is immediate. In either case, the @ref position property changes its value immediately. No UIControlEventValueChanged 
 * is generated.
 *
 * Though the @a position will be forced to lie between the @ref min and @ref max properties, it may otherwise be set to a disallowed position.
 * That is, if mode is IKCModeLinearReturn, the
 * knob may be positioned between discrete positions, and if mode is IKCModeWheelOfFortune, the knob may be positioned exactly
 * on a boundary between segments. If the control is enabled, any subsequent gesture will probably result in a return
 * animation to the nearest allowed position.
 * @param position the new angular position for the knob; will be adjusted to lie within (-M_PI,M_PI] and respect the min and max properties if circular is NO
 * @param animated if YES, animate the transition to the new position; otherwise, the transition is instantaneous
 */
- (void)setPosition:(float)position animated:(BOOL)animated;

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

/**
 * Retrieve the fill color to use for the generated knob image in a particular control state. The @a state argument may be any bitwise combination
 * of UIControlState values, e.g. UIControlStateHighlighted|UIConrolStateDisabled. The fill color for the
 * higher-valued state is returned. For example, in the previous case, since UIControlStateDisabled > UIControlStateHighlighted,
 * the disabled fill color will be returned. If no fill color has been configured for the specified state (e.g., in this example,
 * if there were no disabled fill color specified), returns a color based on the tintColor property.
 * If any of the UIControlStateApplication bits is set, returns the fill color for UIControlStateNormal.
 * @param state any valid control state
 * @return the fill color to use for the specified state
 */
- (UIColor*)fillColorForState:(UIControlState)state;

/**
 * Set the fill color to use for the knob in a specific control state. Unlike the case with fillColorForState:, the @a state parameter
 * must be one of UIControlStateNormal, UIControlStateHighlighted, UIControlStateDisabled or UIControlStateSelected.
 * Mixed states like UIControlStateHighlighted|UIControlStateDisabled will be ignored, and no fill color values will be
 * modified.
 * @param color the fill color to use for the specified state
 * @param state one of UIControlStateNormal, UIcontrolStateHighlighted, UIControlStateDisabled or UIControlStateSelected
 */
- (void)setFillColor:(UIColor*)color forState:(UIControlState)state;

/**
 * Retrieve the title color to use for the generated knob image in a particular control state. The @a state argument may be any bitwise combination
 * of UIControlState values, e.g. UIControlStateHighlighted|UIConrolStateDisabled. The title color for the
 * higher-valued state is returned. For example, in the previous case, since UIControlStateDisabled > UIControlStateHighlighted,
 * the disabled title color will be returned. If no title color has been configured for the specified state (e.g., in this example,
 * if there were no disabled title color specified), returns a color based on the tintColor property.
 * If any of the UIControlStateApplication bits is set, returns the title color for UIControlStateNormal.
 * @param state any valid control state
 * @return the title color to use for the specified state
 */
- (UIColor*)titleColorForState:(UIControlState)state;

/**
 * Set the title color to use for the knob in a specific control state. Unlike the case with titleColorForState:, the @a state parameter
 * must be one of UIControlStateNormal, UIControlStateHighlighted, UIControlStateDisabled or UIControlStateSelected.
 * Mixed states like UIControlStateHighlighted|UIControlStateDisabled will be ignored, and no title color values will be
 * modified.
 * @param color the title color to use for the specified state
 * @param state one of UIControlStateNormal, UIcontrolStateHighlighted, UIControlStateDisabled or UIControlStateSelected
 */
- (void)setTitleColor:(UIColor*)color forState:(UIControlState)state;

/**
 * ICKModeRotaryDial only.
 * Programmatically dial a @a number on the control. This causes the dial to rotate clockwise as though the user had dialed the specified
 * @a number and then to rotate back to the rest position. It generates a UIControlEventValueChanged and sets the value of the
 * positionIndex property to @a number.
 * @param number the number to dial
 */
- (void)dialNumber:(int)number;

@end
