#import <UIKit/UIKit.h>

#if !__has_feature(objc_arc)
#error IOSKnobControl requires automatic reference counting.
#endif // objc_arc

#define IKC_VERSION_STRING @"1.3.0"
#define IKC_VERSION 0x010300
#define IKC_BUILD 1

/*
 * iOS Knob Control
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
    /// Like a circular generalization of the picker view control. The knob turns continuously, but it can only come to rest at certain allowed positions. After being released, it animates to an allowed position at a fixed rate.
    IKCModeLinearReturn,
    /// Like a carnival wheel. Knob can stop at any position in a segment with the exception of narrow strips between them. If it lands very near the boundary between segments, it animates to the closest side.
    IKCModeWheelOfFortune,
    /// Like a circular generalization of the slider control.
    IKCModeContinuous,
    /// Like an old rotary telephone dial.
    IKCModeRotaryDial
};

/**
 * A knob control may be configured to respond to one of several gestures.
 */
typedef NS_ENUM(NSInteger, IKCGesture) {
    /// Custom gesture handling. One finger rotates the knob.
    IKCGestureOneFingerRotation,
    /// Uses the standard iOS two-finger rotation gesture. (Not available with IKCModeRotaryDial.)
    IKCGestureTwoFingerRotation,
    /// Uses a vertical pan gesture. The image still rotates. (Not available with IKCModeRotaryDial.)
    IKCGestureVerticalPan,
    /// Uses a tap gesture. The knob rotates to the position tapped. In rotary dial mode, rotates from the position tapped (dials that number).
    IKCGestureTap
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

/** iOS Knob Control
 * https://github.com/jdee/ios-knob-control
 *
 * This is a simple, reusable rotary control. You may provide custom knob images or use the default images, which may be customized
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
 * If so configured, the control can generate shadows. It will generate at most two: one for the knob image itself and
 * one for the foreground layer. If foregroundImage is nil and mode is not IKCModeRotaryDial, there is no foreground
 * layer and no foreground shadow. In rotary dial mode, the knob control will generate a triangle representing a finger 
 * stop if foregroundImage is nil. Either a supplied foreground image or the finger stop may be configured to cast a
 * shadow. This is done using the shadow parameters in the underlying CALayer. Four IOSKnobControl parameters are passed
 * directly to the layers that cast shadows for the rotating knob and the foreground layer: shadowOffset,
 * shadowOpacity, shadowRadius and shadowColor. Those parameters will be the same for both the knob shadow and any
 * foreground shadow.
 *
 * By default, the CALayer determines where to draw shadows by examining the alpha contents of the layer and filling
 * a path that is the outline of all opaque content in the layer, but slightly offset. However, determining the path to 
 * fill is expensive. On lesser hardware,
 * it can pin the GPU. Supplying a shadowPath to the CALayer can greatly improve performance. This may be done using the
 * middleLayerShadowPath and foregroundLayerShadowPath properties. (Note that if you supply a middleLayerShadowPath, the
 * shadow is generated by an extra layer behind the knob image that rotates with the image but is positioned at the
 * value of shadowOffset. This allows you to supply the outline of the knob image in the stationary coordinate system
 * of the image, independent of rotation.)
 *
 * Since custom images are frequently circular, a knobRadius property is also provided. Set this to provide
 * a circular shadow path of a given radius if using a circular knob image.
 *
 * Setting an appropriate path for a custom rotary dial image is tedious and error-prone, so the control gives you some
 * help. In IKCModeRotaryDial, whether or not you are using a custom image, if you do not set middleLayerShadowPath, the
 * control will generate a shadow path with appropriate finger holes using the knobRadius, fingerHoleMargin
 * and fingerHoleRadius properties. These are used when constructing a rotary dial image. They are also used to generate
 * a shadow path for any custom image, so adjust them to match your image. Note that you cannot vary the angular positions
 * of the numbers and finger holes in your custom images. The control judges which number was dialed by the angular
 * position of the touch, so those cannot vary.
 *
 * Whenever the control generates an image (whenever you do not supply your own image for the knob), it
 * supplies its own shadow path. You usually only need to supply a shadow path when you are using a custom image that is
 * not a solid circle in a mode other than IKCModeRotaryDial. Don't forget to set knobRadius, fingerHoleMargin and
 * fingerHoleRadius when using custom circular images with shadows.
 *
 * By default, shadowOpacity is 0. Set it to a positive value to turn on the default shadow.
 *
 * The knob control requires ARC, and hence iOS 5.0 or later. It has not been tested below iOS 6.1.
 */
@interface IOSKnobControl : UIControl

#pragma mark - Creating a knob control

/**
 * @name Creating a knob control
 */

/**
 * Inherited initializer
 *
 * Inherited from UIView and UIControl. No image specified.
 * @param frame the initial frame for the control
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Initialize the control with an image
 *
 * Initialize the control with a specific knob image for the UIControlStateNormal state.
 * @param frame the initial frame for the control
 * @param image an image to use for the control's normal state
 */
- (instancetype)initWithFrame:(CGRect)frame image:(UIImage*)image;

/**
 * Initialize the control with a specific knob image for the UIControlStateNormal state.
 *
 * The image used will be [UIImage imageNamed:imageSetName]. The image will be selected appropriately for the screen density
 * from the image set named imageSetName in the application's asset catalog.
 * @param frame the initial frame for the control
 * @param imageSetName the name of an image set in the application's asset catalog
 */
- (instancetype)initWithFrame:(CGRect)frame imageNamed:(NSString*)imageSetName;

#pragma mark - Specifying knob control behavior

/**
 * @name Specifying knob control behavior
 */

/** Whether the knob rotates all the way around
 *
 * If this property is set to YES, the circle is closed. That is, all angular positions in (-π, π] are allowed, and -π is identified with π, so it is possible to
 * continue around the circle. The min and max properties of the control are ignored.
 *
 * If this property is set to NO, the circle is open, and the min and max properties are consulted.
 *
 * The default value of this property is YES. It is ignored in IKCModeRotaryDial.
 */
@property (nonatomic) BOOL circular;

/** Whether the position property increases when the knob rotates clockwise (vs. counterclockwise)
 *
 * Specifies whether the value of position increases when the knob is turned clockwise instead of counterclockwise.
 * The default value of this property is NO. It is ignored in IKCModeRotaryDial.
 */
@property (nonatomic) BOOL clockwise;

/** Whether to render certain things asynchronously
 *
 * This property is passed to the animation layers that make up the knob. It can improve response by consuming more resources. Default is NO. See the CALayer class reference for
 * more details.
 */
@property (nonatomic) BOOL drawsAsynchronously;

/** Gesture to use
 *
 * Specifies the gesture the control should recognize. The default is IKCGestureOneFingerRotation.
 * @see IKCGesture
 */
@property (nonatomic) IKCGesture gesture;

/** Maximum value of position
 *
 * Maximum value of the position property if circular == NO. It is ignored in IKCModeRotaryDial. All values are valid, but min and max must be no more than 2π apart. The last one set wins.
 * For example, if you first set min to 0 and max to 3π, min will be adjusted to 2π after max is set. If you set max first and then min, max will be adjusted to π after min is set.
 * In all cases, if the current knob position is outside the allowed range, it will be made to lie within that range after the min or max is adjusted, by setting either to the min or max
 * value.
 */
@property (nonatomic) float max;

/** Minimum value of position
 *
 * Minimum value of the position property if circular == NO. It is ignored in IKCModeRotaryDial. All values are valid, but min and max must be no more than 2π apart. The last one set wins.
 * For example, if you first set min to 0 and max to 3π, min will be adjusted to 2π after max is set. If you set max first and then min, max will be adjusted to π after min is set.
 * In all cases, if the current knob position is outside the allowed range, it will be made to lie within that range after the min or max is adjusted, by setting either to the min or max
 * value.
 */
@property (nonatomic) float min;

/** Overall knob control mode
 *
 * Specifies which mode to use for this knob control. IKCModeLinearReturn is the default.
 * @see IKCMode
 */
@property (nonatomic) IKCMode mode;

/** Whether position is normalized
 *
 * Only consulted if circular is YES. If YES, the position property will always be normalized to lie in (-π, π]. If NO, position can increase or decrease beyond those bounds, allowing
 * determination of the number of complete revolutions. If circular is NO, this property is ignored, and the min and max properties are consulted instead. Defaults to YES.
 */
@property (nonatomic) BOOL normalized;

/** Number of discrete positions
 *
 * Number of discrete positions. Default and minimum are 2. No maximum. (DEBT: Should there be some practical max?) Not consulted in continuous or rotary dial modes.
 */
@property (nonatomic) NSUInteger positions;

/** Animation time scale
 *
 * Used to specify the time scale for return animations.
 * Default is 1.0. The duration of the animation is proportional to this property.
 * Set the number below 1.0 to speed up the animation, and above to slow it down.
 * Return animations will rotate through π/6/timeScale radians per second or
 * through 2π in timeScale x 12 s.
 */
@property (nonatomic) float timeScale;

#pragma mark - Customizing knob control appearance

/**
 * @name Customizing knob control appearance
 */

/** Optional background image
 *
 * If set, the specified image is rendered in the background of the control. The default value is nil.
 *
 * If mode is IKCMRotaryDial, and backgroundImage is nil, the numbers on the dial will be rendered as the
 * background. Use this property to supply your own dial background instead of the generated one.
 */
@property (nonatomic) UIImage* backgroundImage;

/** Finger hole radius
 *
 * Specifies the radius, in points, of finger holes in a generated knob image in IKCModeRotaryDial and when generating a shadow path for rotary dial mode.
 *
 * When using a custom rotary dial image, set this to reflect the size of the finger holes in your image, along with knobRadius. An appropriate
 * shadow path will be generated to match your dial image.
 *
 * Default is 22.
 * @see knobRadius
 */
@property (nonatomic) CGFloat fingerHoleRadius;

/** Finger hole margin
 *
 * Specifies the distance from a finger hole to the edge of the dial. The default value, given the default value of 22 for fingerHoleRadius and the initial frame,
 * is such that the distance between adjacent finger holes is also equal to fingerHoleMargin. If you resize the control or change fingerHoleRadius, fingerHoleMargin
 * does not adjust automatically; you have to set it manually.
 * @see knobRadius
 * @see fingerHoleRadius
 * @see middleLayerShadowPath
 */
@property (nonatomic) CGFloat fingerHoleMargin;

/** Font name for generated titles
 *
 * The font name to use when rendering text in the discrete modes, including rotary dial. Default is Helvetica. The font size is determined by the knob size and the number of positions.
 * CoreText interprets the font name and prefers PostScript names.
 */
@property (nonatomic) NSString* fontName;

/** Optional foreground image
 *
 * An image to render in the foreground. Like the background image, this is totally stationary. The knob image is sandwiched between them and is the only thing
 * that rotates. Obviously the foreground image has to be at least partly transparent. This is mainly useful for providing a stationary finger stop in the foreground of a
 * rotary dial, but it may be used with any mode.
 *
 * If mode is IKCModeRotaryDial, and foregroundImage is nil, a simple stop image is generated around 4:00 on the dial.
 */
@property (nonatomic) UIImage* foregroundImage;

/** Knob radius
 *
 * Used to generate knob images or shadow paths for custom images. Defaults to half the (square) view width in the initial frame.
 *
 * If set to a positive value, the middle layer will be provided with a circular shadow path of the specified radius, in points. The center of the path will be at
 * the center of the control. If you have a custom knob image like the one in the demo apps' Images.xcassets/disc.imageset, where an opaque circle is tangent to
 * the bounds of the image, set knobRadius to half the width or height of the knob control. If your custom image does not reach the bounds of the image but has a
 * transparent margin, set this value to less than half the width or height of the square knob control. You have to reset this value any time the knob control
 * resizes. This property takes precedence over the middleLayerShadowPath property and the default shadow paths generated by the control for its generated images
 * in all modes but IKCModeRotaryDial. If set to 0, this property is ignored, and the middleLayerShadowPath or the automatically generated shadow path will be
 * used instead.
 *
 * When using a custom rotary dial image, set this to reflect the size of the outer dial, along with fingerHoleMargin and fingerHoleRadius. An appropriate
 * shadow path will be generated to match your dial image.
 * @see fingerHoleMargin
 * @see fingerHoleRadius
 */
@property (nonatomic) CGFloat knobRadius;

/** Mask image flag
 * 
 * Ignored when no image is present. If set to YES, the current image may be masked. If the middleLayerShadowPath is set, the image is masked to that path. Otherwise, the image is masked to a circle whose radius is knobRadius.
 * If middleLayerShadowPath is nil and knobRadius is 0 or masksImage is set to NO, no mask is performed. Default is NO.
 */
@property (nonatomic) BOOL masksImage;

/** Titles for generated knob in discrete modes
 *
 * Only used when no image is provided in a discrete mode. These titles are rendered around the knob for each position index. If this property is nil (the default), the position
 * indices will be rendered instead (0, 1, 2, ...). If the length of titles is less than positions, remaining titles will be supplied by indices.
 *
 * Entries may be NSStrings, NSAttributedStrings, or a mix. If an NSAttributedString does not specify the NSFontAttributeName or the NSForegroundColorAttributeName, the
 * attribute will be supplied as for NSStrings (from the currentTitleColor and fontName properties, and the font size will be determined to fit the knob or by zooming the top
 * title). If an attributed string specifies a font, and the zoomTopTitle property is set to YES, the attributed string's font size will be increased. Otherwise, the
 * attributed string's specified attributes will be used. Except for zooming the top title, specified font sizes of attributed strings are never adjusted to fit the knob
 * like plain string titles.
 */
@property (nonatomic) NSArray* titles;

/** Point size to which to zoom top title
 *
 * Only applicable if zoomTopTitle is set in IKCModeLinearReturn or IKCModeWheelOfFortune with no image. Specifies the point size to which the top title should be enlarged.
 * If set to 0, on iOS 7+ the Dynamic Type headline size (i.e., [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleHeadline].pointSize) will be used; on
 * iOS 5 or 6 a 17 pt font will be used. Otherwise, the specified point size will be used. The default is 0.
 */
@property (nonatomic) CGFloat zoomPointSize;

/** Zoom the top title (in case it's too small)
 *
 * Only applicable in IKCModeLinearReturn and IKCModeWheelOfFortune when no image is present, and the knob image is generated from the titles property. If set to YES, the
 * control will enlarge the top title up to a certain size (see zoomPointSize above). The default value is YES.
 */
@property (nonatomic) BOOL zoomTopTitle;

/** Set the image for a given state
 *
 * Set the image to use for a specific control state. Unlike the case with imageForState:, the state parameter
 * must be one of UIControlStateNormal, UIControlStateHighlighted, UIControlStateDisabled or UIControlStateSelected.
 * Mixed states like UIControlStateHighlighted|UIControlStateDisabled will be ignored, and no image values will be
 * modified.
 * @param image the image to use for the specified state
 * @param state one of UIControlStateNormal, UIcontrolStateHighlighted, UIControlStateDisabled or UIControlStateSelected
 */
- (void)setImage:(UIImage *)image forState:(UIControlState)state;

/** Set the fill color for a given state
 *
 * Set the fill color to use for the knob in a specific control state. Unlike the case with fillColorForState:, the state parameter
 * must be one of UIControlStateNormal, UIControlStateHighlighted, UIControlStateDisabled or UIControlStateSelected.
 * Mixed states like UIControlStateHighlighted|UIControlStateDisabled will be ignored, and no fill color values will be
 * modified.
 * @param color the fill color to use for the specified state
 * @param state one of UIControlStateNormal, UIcontrolStateHighlighted, UIControlStateDisabled or UIControlStateSelected
 */
- (void)setFillColor:(UIColor*)color forState:(UIControlState)state;

/** Set the title color for a given state
 *
 * Set the title color to use for the knob in a specific control state. Unlike the case with titleColorForState:, the state parameter
 * must be one of UIControlStateNormal, UIControlStateHighlighted, UIControlStateDisabled or UIControlStateSelected.
 * Mixed states like UIControlStateHighlighted|UIControlStateDisabled will be ignored, and no title color values will be
 * modified.
 * @param color the title color to use for the specified state
 * @param state one of UIControlStateNormal, UIcontrolStateHighlighted, UIControlStateDisabled or UIControlStateSelected
 */
- (void)setTitleColor:(UIColor*)color forState:(UIControlState)state;

#pragma mark - Casting shadows
/**
 * @name Casting shadows
 */

/** Middle layer shadow path
 *
 * If you are using a custom image with circular symmetry, you can greatly improve the performance of the knob control with a shadow by setting this property.
 * Use the knobRadius property if your image is an opaque circle. Use this property if your knob image is, say, an annulus with a transparent center.
 * If the shadow path is not fixed, it has to be computed by the CALayer frame by frame, which is slow. If the knobRadius property is set to a
 * positive value, this property is ignored. The control generates its own shadow paths for the knob images it generates in all modes but IKCModeRotaryDial,
 * unless this property is non-nil or the knobRadius is greater than 0.
 * Default is nil.
 * @see knobRadius
 */
@property (nonatomic) UIBezierPath* middleLayerShadowPath;

/** Foreground layer shadow path
 *
 * Though the foreground layer is stationary, this property is just as important to performance as the middleLayerShadowPath when using a custom foreground
 * image. Set it to the outline of the opaque portion of your custom foregroundImage. This can also override the automatically provided shadow path for the
 * generated finger stop triangle in case that should seem necessary.
 * Default is nil.
 * @see middleLayerShadowPath
 */
@property (nonatomic) UIBezierPath* foregroundLayerShadowPath;

/** Shadow opacity
 *
 * Passed to the CALayer shadowOpacity property for the middle and foreground layers. Default is 0.
 */
@property (nonatomic) CGFloat shadowOpacity;

/** Shadow offset
 *
 * Passed to the CALayer shadowOffset property for the middle and foreground layers. Default is CGSizeMake(0, 3), putting any shadow directly below the knob vertically.
 */
@property (nonatomic) CGSize shadowOffset;

/** Shadow color
 *
 * The CGColor property of this UIColor object is passed to the shadowColor property of the middle and foreground CALayers. Default is [UIColor blackColor].
 */
@property (nonatomic) UIColor* shadowColor;

/** Shadow blur radius
 *
 * Passed to the CALayer shadowRadius property for the middle and foreground layers. Default is 3.
 */
@property (nonatomic) CGFloat shadowRadius;

#pragma mark - Accessing knob control state (position and index)

/**
 * @name Accessing knob control state (position and index)
 */

/** Current knob position
 *
 * Current angular position, in radians, of the knob. Initial value is 0. Limited to (-π, π]. See setPosition:animated: for more details,
 * including the role of the circular, min and max properties. Assigning to this property results in a call to that method, with animated = NO.
 */
@property (nonatomic) float position;

/** Current knob position index
 *
 * Current position index in discrete mode. Which of the positions is selected? This is simply (position-min)/(max-min) x positions. If circular is YES, the min and max
 * properties are ignored, and then positionIndex is (position/2/π) x positions.
 * This property always returns a non-negative number. While position may return a negative angle, positionIndex will range from
 * 0 to positions - 1. For example, if positions is 6 and circular is YES, positionIndex 0 will range from position -π/6 to π/6. The region from
 * -π/2 to -π/6 will have positionIndex 5 instead of -1.
 *
 * In IKCModeRotaryDial, this property is used to represent the number last dialed. This property should be consulted whenever a UIControlEventValueChanged is generated.
 */
@property (nonatomic) NSInteger positionIndex;

/** Set position to a new value
 *
 * Set the position property of the control with or without animation. The specified position will first be constrained to lie between min
 * and max if circular == NO. If the position is greater than max or less than min, it is adjusted to the closest of those values.
 * Next, the value of position is constrained to lie in (-π, π] by adding a (possibly zero or negative) integer multiple of 2π.
 * Finally, the position property is set to this value. If animated is YES, the knob image gradually rotates to the new position;
 * otherwise the visual change is immediate. In either case, the position property changes its value immediately. No UIControlEventValueChanged
 * is generated.
 *
 * Though the position will be forced to lie between the min and max properties, it may otherwise be set to a disallowed position.
 * That is, if mode is IKCModeLinearReturn, the
 * knob may be positioned between discrete positions, and if mode is IKCModeWheelOfFortune, the knob may be positioned exactly
 * on a boundary between segments. If the control is enabled, any subsequent gesture will probably result in a return
 * animation to the nearest allowed position.
 * @param position the new angular position for the knob; will be adjusted to lie within (-π, π] and respect the min and max properties if circular is NO
 * @param animated if YES, animate the transition to the new position; otherwise, the transition is instantaneous
 */
- (void)setPosition:(float)position animated:(BOOL)animated;

#pragma mark - Getting current state

/**
 * @name Getting current state
 */

/** The current fill color
 *
 * The fill color for the current state.
 */
@property (nonatomic, readonly) UIColor* currentFillColor;

/** The current image
 *
 * The image to use for the current state.
 */
@property (nonatomic, readonly) UIImage* currentImage;

/** The current title color
 *
 * The title color to use for the current state.
 */
@property (nonatomic, readonly) UIColor* currentTitleColor;

/** Image for a given state
 *
 * Retrieve the image to use for a particular control state. The state argument may be any bitwise combination
 * of UIControlState values, e.g. UIControlStateHighlighted|UIConrolStateDisabled. The image for the
 * higher-valued state is returned. For example, in the previous case, since UIControlStateDisabled > UIControlStateHighlighted,
 * the disabled image will be returned. If no image has been configured for the specified state (e.g., in this example,
 * if there were no disabled image specified), returns the image for UIControlStateNormal, if any has been set.
 * If any of the UIControlStateApplication bits is set, returns the image for UIControlStateNormal.
 * @param state any valid control state
 * @return the image to use for the specified state
 */
- (UIImage *)imageForState:(UIControlState)state;

/** Fill color for a given state
 *
 * Retrieve the fill color to use for the generated knob image in a particular control state. The state argument may be any bitwise combination
 * of UIControlState values, e.g. UIControlStateHighlighted|UIConrolStateDisabled. The fill color for the
 * higher-valued state is returned. For example, in the previous case, since UIControlStateDisabled > UIControlStateHighlighted,
 * the disabled fill color will be returned. If no fill color has been configured for the specified state (e.g., in this example,
 * if there were no disabled fill color specified), returns a color based on the tintColor property.
 * If any of the UIControlStateApplication bits is set, returns the fill color for UIControlStateNormal.
 * @param state any valid control state
 * @return the fill color to use for the specified state
 */
- (UIColor*)fillColorForState:(UIControlState)state;

/** Title color for a given state
 *
 * Retrieve the title color to use for the generated knob image in a particular control state. The state argument may be any bitwise combination
 * of UIControlState values, e.g. UIControlStateHighlighted|UIConrolStateDisabled. The title color for the
 * higher-valued state is returned. For example, in the previous case, since UIControlStateDisabled > UIControlStateHighlighted,
 * the disabled title color will be returned. If no title color has been configured for the specified state (e.g., in this example,
 * if there were no disabled title color specified), returns a color based on the tintColor property.
 * If any of the UIControlStateApplication bits is set, returns the title color for UIControlStateNormal.
 * @param state any valid control state
 * @return the title color to use for the specified state
 */
- (UIColor*)titleColorForState:(UIControlState)state;

#pragma mark - Dialing a number (rotary dial mode)

/**
 * @name Dialing a number (rotary dial mode)
 */

/** Dial a number
 *
 * ICKModeRotaryDial only.
 * Programmatically dial a number on the control. This causes the dial to rotate clockwise as though the user had dialed the specified
 * number and then to rotate back to the rest position. It generates a UIControlEventValueChanged and sets the value of the
 * positionIndex property to number.
 * @param number the number to dial
 */
- (void)dialNumber:(int)number;

@end
