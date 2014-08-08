/*
 Copyright (c) 2013-14, Jimmy Dee
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <CoreText/CoreText.h>
#import "IOSKnobControl.h"

/*
 * Return animations rotate through this many radians per second when self.timeScale == 1.0.
 */
#define IKC_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE 0.52359878163217 // M_PI/6.0 rad/s

// 1,000 RPM, faster than a finger can reasonably rotate the knob. see comments in followGestureToPosition:duration:
#define IKC_FAST_ANGULAR_VELOCITY (200.0 * IKC_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE)

/*
 * Rotary dial animations are 10 times faster.
 */
#define IKC_ROTARY_DIAL_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE 5.2359878163217 // 5.0*M_PI/3.0 rad/s
#define IKC_EPSILON 1e-7

// this should probably be IKC_MIN_FINGER_HOLE_RADIUS. the actual radius should be a property initialized to this value, and this min. value should be enforced.
// but I'm reluctant to introduce a new property just for rotary dial mode, and I'm not sure whether it's really necessary. it would only be useful for very
// large dials (on an iPad).
#define IKC_FINGER_HOLE_RADIUS 22.0
#define IKC_TITLE_MARGIN_RATIO 0.2

// Must match IKC_VERSION and IKC_BUILD from IOSKnobControl.h.
#define IKC_TARGET_VERSION 0x010300
#define IKC_TARGET_BUILD 1

/*
 * DEBT: Should also do a runtime check in the constructors in case the control is ever built
 * into a library.
 */
#if IKC_TARGET_VERSION != IKC_VERSION || IKC_TARGET_BUILD != IKC_BUILD
#error IOSKnobControl.h version and build do not match IOSKnobControl.m.
#endif // target version/build check

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

static CGRect adjustFrame(CGRect frame) {
    const float IKC_MINIMUM_DIMENSION = ceil(9.72 * IKC_FINGER_HOLE_RADIUS);
    if (frame.size.width < IKC_MINIMUM_DIMENSION) frame.size.width = IKC_MINIMUM_DIMENSION;
    if (frame.size.height < IKC_MINIMUM_DIMENSION) frame.size.height = IKC_MINIMUM_DIMENSION;

    // force the frame to be square. choose the larger of the two dimensions as the square side in case it's not.
    float side = MAX(frame.size.width, frame.size.height);
    frame.size.width = frame.size.height = side;

    return frame;
}

#pragma mark - String deprecation wrapper

@protocol NSStringDeprecatedMethods
- (CGSize)sizeWithFont:(UIFont*)font;
@end

@interface NSString(IKC)
- (CGSize)sizeOfTextWithFont:(UIFont*)font;
@end

@implementation NSString(IKC)

/*
 * For portability among iOS versions.
 */
- (CGSize)sizeOfTextWithFont:(UIFont*)font
{
    CGSize textSize;
    if ([self respondsToSelector:@selector(sizeWithAttributes:)]) {
        // iOS 7+
        textSize = [self sizeWithAttributes:@{NSFontAttributeName: font}];
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

#pragma mark - IKCTextLayer interface
/**
 * Custom text layer. Looks much better than CATextLayer. Destined for the Violation framework.
 */
@interface IKCTextLayer : CALayer

@property (nonatomic, copy) NSString* fontName;
@property (nonatomic) CGFloat fontSize;
@property (nonatomic) CGColorRef foregroundColor;
@property (nonatomic, copy) id string;
@property (nonatomic) CGFloat horizMargin, vertMargin;
@property (nonatomic) BOOL adjustsFontSizeForAttributed;

@property (nonatomic, readonly) CFAttributedStringRef attributedString;

+ (instancetype)layer;

@end

#pragma mark - IKCTextLayer implementation
@implementation IKCTextLayer

+ (instancetype)layer
{
    return [[self alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _fontSize = 0.0;
        _foregroundColor = [UIColor blackColor].CGColor;
        CFRetain(_foregroundColor);
        _horizMargin = _vertMargin = 0.0;
        _adjustsFontSizeForAttributed = NO;

        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor].CGColor;

        [self setNeedsDisplay];
    }
    return self;
}

- (void)dealloc
{
    if (_foregroundColor) CFRelease(_foregroundColor);
}

- (void)setForegroundColor:(CGColorRef)foregroundColor
{
    if (!foregroundColor) return;

    if (_foregroundColor) CFRelease(_foregroundColor);
    _foregroundColor = foregroundColor;
    CFRetain(_foregroundColor);

    [self setNeedsDisplay];
}

- (void)display
{
    /*
     * Scale params for display resolution.
     */
    CGSize size = self.bounds.size;
    CGFloat horizMargin = _horizMargin;
    CGFloat vertMargin = _vertMargin;

    size.width *= [UIScreen mainScreen].scale;
    size.height *= [UIScreen mainScreen].scale;

    horizMargin = _horizMargin * [UIScreen mainScreen].scale;
    vertMargin = _vertMargin * [UIScreen mainScreen].scale;

    /*
     * Get the attributed string to render
     */
    CFAttributedStringRef attributed = self.attributedString;

    // the font used by the attributed string
    CTFontRef font = CFAttributedStringGetAttribute(attributed, 0, kCTFontAttributeName, NULL);
    assert(font);

    // compute vertical position from font metrics
    CGFloat belowBaseline = CTFontGetLeading(font) + CTFontGetDescent(font) + vertMargin;
    CGFloat lineHeight = belowBaseline + CTFontGetAscent(font) + vertMargin;

    // Make a CTLine to render from the attributed string
    CTLineRef line = CTLineCreateWithAttributedString(attributed);
    CFRelease(attributed);

    // Generate a bitmap context at the correct resolution
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    // flip y
    CGContextTranslateCTM(context, 0.0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGFloat x = horizMargin;
    CGFloat y = belowBaseline / lineHeight * size.height;

    CGContextSetTextPosition(context, x, y);
    CTLineDraw(line, context);
    CFRelease(line);

    // Get the generated bitmap and use it for the layer's contents.
    self.contents = (id)UIGraphicsGetImageFromCurrentImageContext().CGImage;
    UIGraphicsEndImageContext();
}

- (CFAttributedStringRef)attributedString
{
    CGFloat fontSize = _fontSize * [UIScreen mainScreen].scale;

    CTFontRef font;

    CFAttributedStringRef attributed;

    /*
     * _string can be an attributed string or a plain string. in the end, we need an attributed string.
     */
    if ([_string isKindOfClass:NSAttributedString.class]) {
        /*
         * It's an attributed string. Make a mutable copy.
         */
        CFMutableAttributedStringRef mutableAttributed = CFAttributedStringCreateMutableCopy(kCFAllocatorDefault, 0, (CFAttributedStringRef)_string);
        attributed = mutableAttributed;

        CFRange wholeString;
        wholeString.location = 0;
        wholeString.length = CFAttributedStringGetLength(attributed);

        font = CFAttributedStringGetAttribute(attributed, 0, kCTFontAttributeName, NULL);

        /*
         * Massage the font attribute for a number of reasons:
         * 1. No font was specified for the input (like a plain string)
         */
        if (!font) {
            font = CTFontCreateWithName((CFStringRef)_fontName, fontSize, NULL);
            CFAttributedStringSetAttribute(mutableAttributed, wholeString, kCTFontAttributeName, font);
            CFRelease(font);
        }
        assert(font);

        CGFloat pointSize = CTFontGetSize(font);
        // NSLog(@"point size for attrib. string: %f", pointSize);

        // 2. It's at the top and has to zoom.
        if (_adjustsFontSizeForAttributed && pointSize != fontSize) {
            /*
             * Need to adjust to the specified fontSize
             */
            CTFontRef newFont = CTFontCreateCopyWithAttributes(font, fontSize, NULL, NULL);
            CFAttributedStringSetAttribute(mutableAttributed, wholeString, kCTFontAttributeName, newFont);
            CFRelease(newFont);
            // NSLog(@"point size for new font: %f", fontSize);
        }
        // 3. This is a high-res image, so we render at double the size.
        else if (!_adjustsFontSizeForAttributed && [UIScreen mainScreen].scale > 1.0) {
            /*
             * Need to increase the font size for this hi-res image
             */
            fontSize = [UIScreen mainScreen].scale * pointSize;

            CTFontRef newFont = CTFontCreateCopyWithAttributes(font, fontSize, NULL, NULL);
            CFAttributedStringSetAttribute(mutableAttributed, wholeString, kCTFontAttributeName, newFont);
            CFRelease(newFont);
            // NSLog(@"point size for new font: %f", fontSize);
        }
        else {
            /*
             * No change. Update the fontName attribute.
             */
            font = CFAttributedStringGetAttribute(attributed, 0, kCTFontAttributeName, NULL);
            _fontName = CFBridgingRelease(CTFontCopyPostScriptName(font));
        }

        /*
         * As with views like UILabel, reset the foregroundColor and fontName properties to those attributes of the
         * string at location 0.
         */
        CGColorRef fg = (CGColorRef)CFAttributedStringGetAttribute(attributed, 0, kCTForegroundColorAttributeName, NULL);
        if (fg) {
            _foregroundColor = (CGColorRef)CFBridgingRetain([UIColor colorWithCGColor: fg]);
        }
        else {
            // no foreground color specified, so give it one (like a plain string)
            CFAttributedStringSetAttribute(mutableAttributed, wholeString, kCTForegroundColorAttributeName, _foregroundColor);
        }

        _fontSize = fontSize / [UIScreen mainScreen].scale;
    }
    else {
        /*
         * Plain string. Get the necessary font.
         */
        font = CTFontCreateWithName((CFStringRef)_fontName, fontSize, NULL);
        assert(font);

        /*
         CFStringRef fname = CTFontCopyPostScriptName(font);
         NSLog(@"Using font %@", (__bridge NSString*)fname);
         CFRelease(fname);
         // */

        CFStringRef keys[] = { kCTFontAttributeName, kCTForegroundColorAttributeName };
        CFTypeRef values[] = { font, _foregroundColor };

        CFDictionaryRef attributes =
        CFDictionaryCreate(kCFAllocatorDefault, (const void**)&keys,
                           (const void**)&values, sizeof(keys) / sizeof(keys[0]),
                           &kCFTypeDictionaryKeyCallBacks,
                           &kCFTypeDictionaryValueCallBacks);
        CFRelease(font);

        // create an attributed string with a foreground color and a font
        attributed = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)_string, attributes);
        CFRelease(attributes);
    }

    return attributed;
}

@end

#pragma mark - IKCAnimationDelegate
/*
 * Used in dialNumber:. There doesn't seem to be an appropriate delegate protocol for CAAnimation. 
 * The animationDidStop:finished: message is
 * simply sent to the delegate object when the animation completes. This method could be in the knob control itself,
 * but the CAAnimation object retains its delegate. It seems likely that the removedOnCompletion flag should make
 * that retention harmless: the imageLayer will eventually release the animation, which in turn will release the
 * control. But this mechanism, using a weak reference to the knob control, avoids that assumption and keeps this
 * method out of the main class, which is a better design.
 */
@interface IKCAnimationDelegate : NSObject
@property (nonatomic, weak) IOSKnobControl* knobControl;
- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag;
@end

@implementation IKCAnimationDelegate
- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
    if (flag == NO) return;
    _knobControl.enabled = YES;
}
@end

#pragma mark - IOSKnobControl implementation

@interface IOSKnobControl()
/*
 * Returns the nearest allowed position
 */
@property (readonly) float nearestPosition;
@end

@implementation IOSKnobControl {
    float touchStart, positionStart, currentTouch;
    UIGestureRecognizer* gestureRecognizer;
    CALayer* imageLayer, *backgroundLayer, *foregroundLayer, *middleLayer;
    CAShapeLayer* shapeLayer, *pipLayer, *stopLayer;
    NSMutableArray* markings, *dialMarkings;
    UIImage* images[4];
    UIColor* fillColor[4];
    UIColor* titleColor[4];
    BOOL rotating;
    int lastNumberDialed, _numberDialed;
    NSInteger lastPositionIndex;
}

@dynamic positionIndex, nearestPosition;

#pragma mark - Object Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setDefaults];
        [self setupGestureRecognizer];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame image:(UIImage *)image
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setImage:image forState:UIControlStateNormal];
        [self setDefaults];
        [self setupGestureRecognizer];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame imageNamed:(NSString *)imageSetName
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImage* image = [UIImage imageNamed:imageSetName];
        [self setImage:image forState:UIControlStateNormal];
        [self setDefaults];
        [self setupGestureRecognizer];
    }
    return self;
}

- (void)setDefaults
{
    _mode = IKCModeLinearReturn;
    _clockwise = NO;
    _position = 0.0;
    _circular = YES;
    _min = -M_PI + IKC_EPSILON;
    _max = M_PI - IKC_EPSILON;
    _positions = 2;
    _timeScale = 1.0;
    _gesture = IKCGestureOneFingerRotation;
    _normalized = YES;
    _fontName = @"Helvetica";
    _shadow = NO;
    _zoomTopTitle = YES;

    rotating = NO;
    lastNumberDialed = _numberDialed = -1;

    lastPositionIndex = 0;

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
        [self setNeedsLayout];
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
        [self setNeedsLayout];
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
        [self setNeedsLayout];
    }
}

- (void)setFrame:(CGRect)frame
{
    if (_mode == IKCModeRotaryDial)
    {
        frame = adjustFrame(frame);
    }
    [super setFrame:frame];
    [self setNeedsLayout];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    _backgroundImage = backgroundImage;
    [self setNeedsLayout];
}

- (void)setForegroundImage:(UIImage *)foregroundImage
{
    _foregroundImage = foregroundImage;
    [self setNeedsLayout];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    gestureRecognizer.enabled = enabled;

    [self updateControlState];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self updateControlState];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self updateControlState];
}

- (void)setPositions:(NSUInteger)positions
{
    if (_positions == positions) return;

    _positions = positions;

    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self addMarkings]; // gets rid of any old ones
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
    [self setNeedsLayout];

    if (_mode == IKCModeRotaryDial)
    {
        if (_gesture == IKCGestureVerticalPan || _gesture == IKCGestureTwoFingerRotation)
        {
            _gesture = IKCGestureOneFingerRotation;
        }
        _clockwise = NO; // dial clockwise, but all calcs assume ccw
        _circular = NO;
        _max = IKC_EPSILON;
        _min = -11.0*M_PI/6.0;
        self.frame = adjustFrame(self.frame);
        lastNumberDialed = 0;
    }
}

- (void)setCircular:(BOOL)circular
{
    if (_mode == IKCModeRotaryDial) return;
    _circular = circular;

    if (!_circular) {
        self.position = MIN(MAX(_position, _min), _max);
    }
    else if (_normalized) {
        while (_position > M_PI) _position -= 2.0 * M_PI;
        while (_position <= -M_PI) _position += 2.0 * M_PI;
    }

    [self setNeedsLayout];
}

- (void)setClockwise:(BOOL)clockwise
{
    if (_mode == IKCModeRotaryDial) return;

    _clockwise = clockwise;
    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self.layer addSublayer:imageLayer];
    [self setNeedsLayout];
}

- (void)setPosition:(float)position
{
    [self setPosition:position animated:NO];
}

- (void)setPosition:(float)position animated:(BOOL)animated
{
    if (_circular == NO) {
        position = MAX(position, _min);
        position = MIN(position, _max);
    }
    else if (_normalized) {
        while (position > M_PI) position -= 2.0*M_PI;
        while (position <= -M_PI) position += 2.0*M_PI;
        if (position == -M_PI) position = M_PI;
    }
    float delta = fabs(position - _position);

    // ignore _timeScale. rotate through 2*M_PI in 1 s.
    [self returnToPosition:position duration:animated ? delta*0.5/M_PI : 0.0];
}

- (void)setPositionIndex:(NSInteger)positionIndex
{
    if (self.mode == IKCModeContinuous || self.mode == IKCModeRotaryDial) return;

    float position = self.circular ? (2.0*M_PI/_positions)*positionIndex : ((self.max - self.min)/_positions)*(positionIndex+0.5) + self.min;
    [self setPosition:position animated:NO];
}

- (NSInteger)positionIndex
{
    if (self.mode == IKCModeContinuous) return -1;
    if (self.mode == IKCModeRotaryDial) return lastNumberDialed;
    return [self positionIndexForPosition:_position];
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
    // this property is effectively readonly in this mode
    if (_mode == IKCModeRotaryDial) return;

    _min = min;

    if (_max - _min >= 2.0*M_PI) _max = _min + 2.0*M_PI;
    if (_max < _min) _max = _min;

    if (_position < _min) self.position = _min;

    if (_mode == IKCModeContinuous || self.currentImage) return;

    // if we are rendering a discrete knob with titles, re-render the titles now that min/max has changed
    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self.layer addSublayer:imageLayer];
}

- (void)setMax:(float)max
{
    // this property is effectively readonly in this mode
    if (_mode == IKCModeRotaryDial) return;

    _max = max;

    if (_max - _min >= 2.0*M_PI) _min = _max - 2.0*M_PI;
    if (_max < _min) _min = _max;

    if (_position > _max) self.position = _max;

    if (_mode == IKCModeContinuous || self.currentImage) return;

    // if we are rendering a discrete knob with titles, re-render the titles now that min/max has changed
    [imageLayer removeFromSuperlayer];
    shapeLayer = nil;
    imageLayer = [self createShapeLayer];
    [self.layer addSublayer:imageLayer];
}

- (void)setGesture:(IKCGesture)gesture
{
    if (_mode == IKCModeRotaryDial && (gesture == IKCGestureTwoFingerRotation || gesture == IKCGestureVerticalPan))
    {
#ifdef DEBUG
        NSLog(@"IKCModeRotaryDial only allows IKCGestureOneFingerRotation and IKCGestureTap");
#endif // DEBUG
        return;
    }

    _gesture = gesture;
    [self setupGestureRecognizer];
}

- (void)setNormalized:(BOOL)normalized
{
    _normalized = normalized;

    if (!_circular) {
        self.position = MIN(MAX(_position, _min), _max);
    }
    else if (_normalized) {
        while (_position > M_PI) _position -= 2.0 * M_PI;
        while (_position <= -M_PI) _position += 2.0 * M_PI;
    }

    [self setNeedsLayout];
}

- (void)setFontName:(NSString *)fontName
{
    UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:fontName size:0.0];
    if ([fontDescriptor matchingFontDescriptorsWithMandatoryKeys:nil].count == 0) {
        /*
         * On iOS 6, the matchingBlah: call returns 0 for valid fonts. So we do this check too
         * before giving up.
         */
        UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:fontName size:17.0];
        if (![UIFont fontWithDescriptor:fontDescriptor size:0.0] && ![UIFont fontWithName:fontName size:17.0]) {
            NSLog(@"Failed to find font name \"%@\".", fontName);
            return;
        }
    }

    _fontName = fontName;
    [self setNeedsLayout];
}

- (void)setShadow:(BOOL)shadow
{
    _shadow = shadow;
    [self setNeedsLayout];
}

- (void)setZoomTopTitle:(BOOL)zoomTopTitle
{
    _zoomTopTitle = zoomTopTitle;
    [self setNeedsLayout];
}

- (void)tintColorDidChange
{
    [self setNeedsLayout];
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
    if (_mode != IKCModeRotaryDial) return;
    if (number < 0 || number > 9) return;

    lastNumberDialed = number;

    if (number == 0) number = 10;

    // now animate

    double farPosition = (number + 1) * M_PI/6.0;
    double adjusted = -_position;
    while (adjusted < 0) adjusted += 2.0*M_PI;
    double totalRotation = 2.0*farPosition - adjusted;

    IKCAnimationDelegate* delegate = [[IKCAnimationDelegate alloc] init];
    delegate.knobControl = self;

    self.enabled = NO;

    [CATransaction new];
    [CATransaction setDisableActions:YES];
    imageLayer.transform = CATransform3DMakeRotation(0.0, 0, 0, 1);
    _position = 0.0;

    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    animation.values = @[@(adjusted), @(farPosition), @(0.0)];
    animation.keyTimes = @[@(0.0), @((farPosition-adjusted)/totalRotation), @(1.0)];
    animation.duration = _timeScale / IKC_ROTARY_DIAL_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE * totalRotation;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    animation.delegate = delegate;

    [imageLayer addAnimation:animation forKey:nil];

    [CATransaction commit];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    lastPositionIndex = self.positionIndex;
    [self updateImage];
}

#pragma mark - Private Methods: Geometry

- (void)checkPositionIndex
{
    if (self.positionIndex == lastPositionIndex) {
        return;
    }

    lastPositionIndex = self.positionIndex;
    [self setNeedsLayout];
}

- (NSInteger)positionIndexForPosition:(float)position
{
    if (!_circular && position == _max) {
        return _positions - 1;
    }

    float converted = position;
    if (converted < 0) converted += 2.0*M_PI;

    int index = _circular ? converted*0.5/M_PI*_positions+0.5 : (position-_min)/(_max-_min)*_positions;

    if (index < 0)
    {
        index += ceil(-(double)index/(double)_positions) * _positions;
    }

    return index % _positions;
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

- (float)nearestPosition
{
    return [self nearestPositionToPosition:_position];
}

/*
 * Not normalized to (-M_PI,M_PI].
 */
- (float)nearestPositionToPosition:(float)position
{
    NSInteger positionIndex = [self positionIndexForPosition:position];
    if (_circular) {
        if (2*positionIndex == _positions) {
            /*
             * Try to keep things confined to (-M_PI,M_PI] and avoid a return to -M_PI.
             * This only happens when circular is YES.
             * https://github.com/jdee/ios-knob-control/issues/7
             */
            return M_PI - IKC_EPSILON;
        }
        return positionIndex*2.0*M_PI/_positions;
    }

    return ((_max-_min)/_positions)*(positionIndex+0.5) + _min;
}

#pragma mark - Private Methods: Animation

- (void)snapToNearestPosition
{
    [self snapToNearestPositionWithPosition:_position duration:-1.0];
}

- (void)snapToNearestPositionWithPosition:(float)position duration:(float)duration
{
    /*
     * Animate return to nearest position
     */
    float nearestPositionAngle = [self nearestPositionToPosition:position];
    float delta = nearestPositionAngle - _position;

    while (delta > M_PI) {
        nearestPositionAngle -= 2.0*M_PI;
        delta -= 2.0*M_PI;
    }
    while (delta <= -M_PI) {
        nearestPositionAngle += 2.0*M_PI;
        delta += 2.0*M_PI;
    }

    // DEBT: Make these constants macros, properties, something.
    const float threshold = 0.9*M_PI/_positions;

    switch (self.mode) {
        case IKCModeWheelOfFortune:
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
        // The largest absolute value of delta is M_PI/self.positions, halfway between segments.
        // If delta is M_PI/self.positions, the duration is maximal. Otherwise, it scales linearly.
        // Without this adjustment, the animation will seem much faster for large
        // deltas.

        duration = _timeScale/IKC_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE*fabs(delta);
    }

    [self returnToPosition:nearestPositionAngle duration:duration];
}

- (void)returnToPosition:(float)position duration:(float)duration
{
    if (position == _position) return;

    float actual = self.clockwise ? position : -position;
    float current = self.clockwise ? _position : -_position;

    // the CALayer already makes the rotation go the right way. this makes our computation of the minDuration
    // accurate.
    while (actual > current + M_PI) actual -= 2.0*M_PI;
    while (actual <= current - M_PI) actual += 2.0*M_PI;

    // Calling this method with duration == 0.0 previously elided the animation
    // below and just assigned a new value to the transform property of the imageLayer. On iOS 7+, at least,
    // this change was not instantaneous, and the default rotation rate for the CALayer was not fast enough to keep up with a
    // quick finger. As a result, although (or perhaps because) pan events are received frequently when using IKCGestureOneFingerRotation,
    // repeated assignments to the transform property without using an explicit animation usually made the control lag.
    // Apparently it would eventually drop some of those
    // transforms from its queue in an attempt to catch up and would end up rotating in the wrong direction.
    // Since eliminating that in favor of this fast animation, the behavior of the knob under rotation has changed. Previously,
    // I was used to watching the pip on the default knob image lag behind my finger if I started with the finger on top of the
    // pip. Now the knob tracks so well, I can never see the pip; it's always right under my finger. Huzzah!
    float minDuration = fabsf(actual-current)/IKC_FAST_ANGULAR_VELOCITY;
    duration = MAX(minDuration, fabsf(duration));

    // Gratefully borrowed from http://www.raywenderlich.com/56885/custom-control-for-ios-tutorial-a-reusable-knob
    [CATransaction new];
    [CATransaction setDisableActions:YES];
    imageLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);

    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"];
    animation.values = @[@(current), @(actual)];
    animation.keyTimes = @[@(0.0), @(1.0)];
    animation.duration = duration;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];

    [imageLayer addAnimation:animation forKey:nil];
        
    [CATransaction commit];

    _position = position;

    if (_mode == IKCModeLinearReturn || _mode == IKCModeWheelOfFortune) {
        [self checkPositionIndex];
    }
}

#pragma mark - Private Methods: Gesture Recognition

- (void)setupGestureRecognizer
{
    if (gestureRecognizer) [self removeGestureRecognizer:gestureRecognizer];

    if (_gesture == IKCGestureOneFingerRotation) {
        gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    }
    else if (_gesture == IKCGestureTwoFingerRotation) {
        gestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation:)];
    }
    else if (_gesture == IKCGestureVerticalPan) {
        gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleVerticalPan:)];
    }
    else if (_gesture == IKCGestureTap)
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
        if (_mode == IKCModeRotaryDial) {
            _numberDialed = numberDialed([self polarAngleOfPoint:centerFrameBegin]);
        }
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
    NSLog(@"knob turned. state = %s, touchStart = %f, positionStart = %f, touch = %f, position = %f (min=%f, max=%f), _position = %f",
          (sender.state == UIGestureRecognizerStateBegan ? "began" :
           sender.state == UIGestureRecognizerStateChanged ? "changed" :
           sender.state == UIGestureRecognizerStateEnded ? "ended" :
           sender.state == UIGestureRecognizerStateCancelled ? "cancelled" : "<misc>"), touchStart, positionStart, touch, position, _min, _max, _position);
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
    float r = NAN;

    switch (self.mode)
    {
        case IKCModeContinuous:
            // DEBT: This is the first gesture that provides an absolute position. Previously all gestures
            // only rotated the image *by* a certain amount. This gesture rotates the image *to* a specific
            // position. This assumes a certain orientation of the image. For now, assume the pointer is
            // at the top.
            self.position = position - M_PI_2;
            break;
        case IKCModeLinearReturn:
        case IKCModeWheelOfFortune:
            // DEBT: And that works poorly with discrete modes. If I tap Feb, it doesn't mean I want Jan to
            // rotate to that point. It means I want Feb at the top. Things would work the same as the
            // continuous mode if you had discrete labels and something like the continuous knob image.
            // For now:
            [self snapToNearestPositionWithPosition:_position-position+M_PI_2 duration:0.0];
            break;
        case IKCModeRotaryDial:
            // This is the reason this gesture was introduced. The user can simply tap a number on the dial,
            // and the dial will rotate around and back as though they had dialed.

            // desensitize the center region
            /*
             * The finger holes are positioned so that the distance between adjacent holes is the same as
             * the margin between the hole and the perimeter of the outer dial. This implies a relationship
             * among the quantities
             * R, the radius of the dial (self.frame.size.width*0.5 or self.frame.size.height*0.5),
             * f, the radius of each finger hole, and
             * m, the margin around each finger hole:
             * R = 4.86*f + 2.93*m.
             * 4.86 = 1.0 + 1.0/sin(M_PI/12.0);
             * 2.93 = 1.0 + 0.5/sin(M_PI/12.0);
             */
            r = sqrt(inCenterFrame.x * inCenterFrame.x + inCenterFrame.y * inCenterFrame.y);
#ifdef DEBUG
            NSLog(@"Tapped %f pts from center; threshold is %f", r, self.frame.size.width*0.294);
#endif // DEBUG

            // distance from the center must be at least R - 2f - m. The max. value of f is R/4.86, so given that a custom
            // image may make the finger holes any size, we allow for the largest value of 2f + m, which occurs when m = 0
            if (r < self.frame.size.width*0.294) return;

            [self dialNumber:numberDialed(position)];
            [self sendActionsForControlEvents:UIControlEventValueChanged];
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
            if (self.mode == IKCModeLinearReturn || self.mode == IKCModeWheelOfFortune)
            {
                [self snapToNearestPosition];
            }
            else if (self.mode == IKCModeRotaryDial && sender.state == UIGestureRecognizerStateEnded)
            {
                double delta = currentTouch - touchStart;
                while (delta <= -2.0*M_PI) delta += 2.0*M_PI;
                while (delta > 0.0) delta -= 2.0*M_PI;

                /*
                 * Delta is unsigned and just represents the absolute angular distance the knob was rotated before being
                 * released. It may only be rotated in the negative direction, however, since max is 0.0.
                 * What matters is _numberDialed, which is determined
                 * by the starting touch, and how far the knob/dial has traveled from its rest position when released. 
                 * The user just has to drag the knob at least 45 degrees in order to trigger a dial.
                 */

                // DEBT: Review, externalize this threshold (-M_PI_4)?
                if (_numberDialed < 0 || _numberDialed > 9 || delta > -M_PI_4 || sender.state == UIGestureRecognizerStateCancelled)
                {
                    [self returnToPosition:0.0 duration:_timeScale/IKC_ROTARY_DIAL_ANGULAR_VELOCITY_AT_UNIT_TIME_SCALE*fabs(position)];
                }
                else
                {
                    [self dialNumber:_numberDialed];
                    [self sendActionsForControlEvents:UIControlEventValueChanged];
                }
            }

            rotating = NO;

            // revert from highlighted to normal
            [self updateControlState];
            break;
        default:
            // just track the touch while the gesture is in progress
            self.position = position;
            rotating = YES;
            break;
    }

    if (_mode != IKCModeRotaryDial)
    {
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

#pragma mark - Private Methods: Image Management

- (UIFont*)fontWithSize:(CGFloat)fontSize
{
    /*
     * Different things work in different environments, so:
     */

    UIFontDescriptor* fontDescriptor = [UIFontDescriptor fontDescriptorWithName:_fontName size:fontSize];
    UIFont* font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
    if (font) return font;

    return [UIFont fontWithName:_fontName size:fontSize];
}

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
    self.layer.bounds = self.bounds;
    self.layer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);
    /*
     * There is always a background layer. It may just have no contents and no
     * sublayers.
     */
    if (!backgroundLayer)
    {
        backgroundLayer = [CALayer layer];
        backgroundLayer.backgroundColor = [UIColor clearColor].CGColor;
        backgroundLayer.opaque = NO;
        [self.layer addSublayer:backgroundLayer];
    }
    backgroundLayer.bounds = self.bounds;
    backgroundLayer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);

    if (_backgroundImage)
    {
        backgroundLayer.contents = (id)_backgroundImage.CGImage;
        for (CALayer* layer in dialMarkings)
        {
            [layer removeFromSuperlayer];
        }
        dialMarkings = nil;
    }
    else if (_mode == IKCModeRotaryDial)
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

    if (!middleLayer)
    {
        middleLayer = [CALayer layer];
        middleLayer.backgroundColor = [UIColor clearColor].CGColor;
        middleLayer.opaque = NO;
        [self.layer addSublayer:middleLayer];
    }
    middleLayer.bounds = self.bounds;
    middleLayer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);
    middleLayer.shadowOpacity = _shadow ? 1.0 : 0.0;
    middleLayer.shadowOffset = CGSizeMake(0, 3); // DEBT: Make all the shadow params configurable

    UIImage* image = self.currentImage;
    if (image) {
        if ([imageLayer isKindOfClass:CAShapeLayer.class]) {
            [imageLayer removeFromSuperlayer];
            imageLayer = nil;
        }

        if (!imageLayer) {
            imageLayer = [CALayer layer];
            imageLayer.backgroundColor = [UIColor clearColor].CGColor;
            imageLayer.opaque = NO;

            float actual = self.clockwise ? self.position : -self.position;
            imageLayer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);

            [middleLayer addSublayer:imageLayer];
        }

        imageLayer.contents = (id)image.CGImage;
    }
    else {
        [imageLayer removeFromSuperlayer];
        if (![imageLayer isKindOfClass:CAShapeLayer.class]) {
            imageLayer = [self createShapeLayer];
        }
        [middleLayer addSublayer:imageLayer];
    }
    imageLayer.bounds = self.bounds;
    imageLayer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);

    if (_foregroundImage || _mode == IKCModeRotaryDial)
    {
        [foregroundLayer removeFromSuperlayer];
        foregroundLayer = [CALayer layer];
        foregroundLayer.bounds = self.bounds;
        foregroundLayer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);
        foregroundLayer.backgroundColor = [UIColor clearColor].CGColor;
        foregroundLayer.opaque = NO;
        foregroundLayer.shadowOpacity = _shadow ? 1.0 : 0.0;
        foregroundLayer.shadowOffset = CGSizeMake(0, 3);
        [self.layer addSublayer:foregroundLayer];

        if (_foregroundImage)
        {
            [stopLayer removeFromSuperlayer];
            stopLayer = nil;
            foregroundLayer.contents = (id)_foregroundImage.CGImage;
        }
        else
        {
            foregroundLayer.contents = nil;
            [self createDialStop];
            [foregroundLayer addSublayer:stopLayer];
        }
    }
    else
    {
        [stopLayer removeFromSuperlayer];
        stopLayer = nil;
        [foregroundLayer removeFromSuperlayer];
        foregroundLayer = nil;
    }

    [self updateShapeLayer];
}

- (void)updateShapeLayer
{
    if (!self.currentImage) {
        switch (_mode) {
            case IKCModeLinearReturn:
            case IKCModeWheelOfFortune:
                [self updateKnobWithMarkings];
                break;
            case IKCModeRotaryDial:
                [self updateRotaryDial];
                break;
            default:
                break;
        }

        [self updateControlState];
    }
}

/*
 * There are several things that require a full layout: Changing the appearance of the control (image vs. none, different font size, etc.),
 * changing the frame (resizing). And many other things, like changing the background image, redraw the control entirely because it's
 * easier to call setNeedsLayout than it is to factor out the pieces that are affected by each possible property change.
 * 
 * However, control state changes frequently, and the changes have to be fast to avoid interfering with animations. Hence this separate method
 * called whenever state changes.
 */
- (void)updateControlState
{
    if (self.currentImage) {
        imageLayer.contents = (id)self.currentImage.CGImage;
    }
    else {
        shapeLayer.fillColor = self.currentFillColor.CGColor;
        pipLayer.fillColor = self.currentTitleColor.CGColor;
        stopLayer.fillColor = self.currentTitleColor.CGColor;

        for (IKCTextLayer* layer in markings) {
            layer.foregroundColor = self.currentTitleColor.CGColor;
        }
    }
}

- (void)updateKnobWithMarkings
{
    shapeLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5) radius:self.bounds.size.width*0.45 startAngle:0.0 endAngle:2.0*M_PI clockwise:NO].CGPath;
    shapeLayer.bounds = self.bounds;
    shapeLayer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);

    [self updateMarkings];
}

- (void)updateRotaryDial
{
    float const dialRadius = 0.5 * self.bounds.size.width;
    UIBezierPath* path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5) radius:dialRadius startAngle:0.0 endAngle:2.0*M_PI clockwise:NO];

    // this follows because the holes are positioned so that the margin between adjacent holes
    // is the same as the margin between each hole and the rim of the dial. see the discussion
    // in handleTap:. the radius of a finger hole is constant, 22 pts, for a 44 pt diameter,
    // the minimum size for a tap target. the minimum value of dialRadius is 107. the control
    // must be at least 214x214.
    float const margin = (dialRadius - 4.86*IKC_FINGER_HOLE_RADIUS)/2.93;
    float const centerRadius = dialRadius - margin - IKC_FINGER_HOLE_RADIUS;

    int j;
    for (j=0; j<10; ++j)
    {
        double centerAngle = M_PI_4 + j*M_PI/6.0;
        double centerX = self.bounds.size.width*0.5 + centerRadius * cos(centerAngle);
        double centerY = self.bounds.size.height*0.5 - centerRadius * sin(centerAngle);
        [path addArcWithCenter:CGPointMake(centerX, centerY) radius:IKC_FINGER_HOLE_RADIUS startAngle:M_PI_2-centerAngle endAngle:1.5*M_PI-centerAngle clockwise:YES];
    }
    for (--j; j>=0; --j)
    {
        double centerAngle = M_PI_4 + j*M_PI/6.0;
        double centerX = self.bounds.size.width*0.5 + centerRadius * cos(centerAngle);
        double centerY = self.bounds.size.height*0.5 - centerRadius * sin(centerAngle);
        [path addArcWithCenter:CGPointMake(centerX, centerY) radius:IKC_FINGER_HOLE_RADIUS startAngle:1.5*M_PI-centerAngle endAngle:M_PI_2-centerAngle clockwise:YES];
    }

    shapeLayer.path = path.CGPath;
    shapeLayer.bounds = self.bounds;
    shapeLayer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);
}

- (void)updateDialNumbers
{
    float const dialRadius = 0.5 * self.bounds.size.width;

    // this follows because the holes are positioned so that the margin between adjacent holes
    // is the same as the margin between each hole and the rim of the dial. see the discussion
    // in handleTap:. the radius of a finger hole is constant, 22 pts, for a 44 pt diameter,
    // the minimum size for a tap target. the minimum value of dialRadius is 107. the control
    // must be at least 214x214.
    float const margin = (dialRadius - 4.86*IKC_FINGER_HOLE_RADIUS)/2.93;
    float const centerRadius = dialRadius - margin - IKC_FINGER_HOLE_RADIUS;

    CGFloat fontSize = 17.0;
    if ([UIFontDescriptor respondsToSelector:@selector(preferredFontDescriptorWithTextStyle:)]) {
        fontSize = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleHeadline].pointSize;
    }

    UIFont* font = [UIFont fontWithName:_fontName size:fontSize];
    int j;
    for (j=0; j<10; ++j)
    {
        double centerAngle = M_PI_4 + j*M_PI/6.0;
        double centerX = self.bounds.size.width*0.5 + centerRadius * cos(centerAngle);
        double centerY = self.bounds.size.height*0.5 - centerRadius * sin(centerAngle);

        NSString* text = [NSString stringWithFormat:@"%d", (j + 1) % 10];
        CGSize textSize = [text sizeOfTextWithFont:font];
        IKCTextLayer* textLayer = dialMarkings[j];
        textLayer.string = text;
        textLayer.foregroundColor = self.currentTitleColor.CGColor;
        textLayer.fontSize = fontSize;
        textLayer.fontName = _fontName;

        textLayer.bounds = CGRectMake(0, 0, textSize.width, textSize.height);
        textLayer.position = CGPointMake(centerX, centerY);
        /*
        textLayer.borderColor = self.currentTitleColor.CGColor;
        textLayer.borderWidth = 1.0;
        textLayer.cornerRadius = 2.0;
        // */

        [textLayer setNeedsDisplay];

        [dialMarkings addObject:textLayer];
        [backgroundLayer addSublayer:textLayer];
    }
}

- (void)updateMarkings
{
    CGFloat fontSize = self.fontSizeForTitles;
    UIFont* font = [self fontWithSize:fontSize];
    assert(font);

    /*
     * Zoom the title at the top to the headline size if fontSize is smaller than the current headline font size
     * (makes use of Dynamic Type, so requires iOS 7+). DEBT: Zoom to 17 pts or something on iOS 6?
     */
    UIFont* headlineFont = font;
    CGFloat headlinePointSize = font.pointSize;
    if (_zoomTopTitle && [UIFontDescriptor respondsToSelector:@selector(preferredFontDescriptorWithTextStyle:)]) {
        // iOS 7+
        UIFontDescriptor* headlineFontDesc = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleHeadline];
        if (headlineFontDesc.pointSize > fontSize) {
            headlinePointSize = headlineFontDesc.pointSize;
            headlineFont = [self fontWithSize:headlinePointSize];
            assert(headlineFont);
        }
    }
    else if (_zoomTopTitle) {
        // iOS 5 & 6
        headlinePointSize = 17.0;
        if (headlinePointSize > fontSize) {
            headlineFont = [self fontWithSize:headlinePointSize];
            assert(headlineFont);
        }
    }

    assert(font);
    assert(headlineFont);

    assert(markings.count == _positions);

    int j;
    for (j=0; j<_positions; ++j) {
        // get the title for this marking (use j if none)
        NSString* title;
        NSAttributedString* attribTitle;
        id titleObject;
        if (j < _titles.count) titleObject = [_titles objectAtIndex:j];

        if (!titleObject) {
            title = [NSString stringWithFormat:@"%d", j];
        }
        else if ([titleObject isKindOfClass:NSAttributedString.class]) {
            attribTitle = titleObject;
        }
        else if ([titleObject isKindOfClass:NSString.class]) {
            title = titleObject;
        }

        NSInteger currentIndex = self.positionIndex;
        UIFont* titleFont = currentIndex == j ? headlineFont : font;
        CGFloat pointSize = currentIndex == j ? headlinePointSize : fontSize;

        // NSLog(@"Using title font %@, %f", titleFont.fontName, titleFont.pointSize);

        // These computations need work.
        CGSize textSize;

        if (attribTitle) {
            textSize = _zoomTopTitle && currentIndex == j ? [attribTitle.string sizeOfTextWithFont:titleFont] : attribTitle.size;
        }
        else if (title) {
            textSize = [title sizeOfTextWithFont:titleFont];
        }
        CGFloat horizMargin = IKC_TITLE_MARGIN_RATIO * textSize.width;
        CGFloat vertMargin = IKC_TITLE_MARGIN_RATIO * textSize.height;

        textSize.width += 2.0 * horizMargin;
        textSize.height += 2.0 * vertMargin;
        
        IKCTextLayer* layer = markings[j];

        layer.string = titleObject;
        layer.horizMargin = horizMargin;
        layer.vertMargin = vertMargin;
        layer.adjustsFontSizeForAttributed = _zoomTopTitle && currentIndex == j;

        // these things are all ignored if layer.string is an attributed string
        layer.fontSize = pointSize; // except this if adjustsFontSizeForAttributed is set
        layer.fontName = _fontName;
        layer.foregroundColor = self.currentTitleColor.CGColor;

        // place it at the appropriate angle, taking the clockwise switch into account
        float position;
        if (self.circular) {
            position = (2.0*M_PI/_positions)*j;
        }
        else {
            position = ((_max-_min)/_positions)*(j+0.5) + _min;
        }

        float actual = _clockwise ? -position : position;

        // distance from the center to place the upper left corner
        float radius = 0.45*self.bounds.size.width - 0.5*textSize.height;

        // place and rotate
        layer.position = CGPointMake(self.bounds.origin.x + 0.5*self.bounds.size.width+radius*sin(actual), self.bounds.origin.y + 0.5*self.bounds.size.height-radius*cos(actual));
        layer.bounds = CGRectMake(0, 0, textSize.width, textSize.height);
        layer.transform = CATransform3DMakeRotation(actual, 0, 0, 1);

        /*
        layer.borderColor = self.currentTitleColor.CGColor;
        layer.borderWidth = 1.0;
        layer.cornerRadius = 2.0;
        // */

        [layer setNeedsDisplay];
    }
}

- (void)addMarkings
{
    for (CATextLayer* layer in markings) {
        [layer removeFromSuperlayer];
    }
    markings = [NSMutableArray array];

    int j;
    for (j=0; j<_positions; ++j) {
        IKCTextLayer* layer = [IKCTextLayer layer];
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
    switch (_mode)
    {
        case IKCModeContinuous:
            [self createKnobWithPip];
            break;
        case IKCModeLinearReturn:
        case IKCModeWheelOfFortune:
            [self createKnobWithMarkings];
            break;
        case IKCModeRotaryDial:
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

    return shapeLayer;
}

- (CAShapeLayer*)createKnobWithPip
{
    shapeLayer = [CAShapeLayer layer];
    shapeLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.5) radius:self.bounds.size.width*0.45 startAngle:0.0 endAngle:2.0*M_PI clockwise:NO].CGPath;
    shapeLayer.bounds = self.bounds;
    shapeLayer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);
    shapeLayer.backgroundColor = [UIColor clearColor].CGColor;
    shapeLayer.opaque = NO;

    for (CATextLayer* layer in markings) {
        [layer removeFromSuperlayer];
    }
    markings = nil;

    pipLayer = [CAShapeLayer layer];
    pipLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(self.bounds.size.width*0.5, self.bounds.size.height*0.1) radius:self.bounds.size.width*0.03 startAngle:0.0 endAngle:2.0*M_PI clockwise:NO].CGPath;
    pipLayer.bounds = self.bounds;
    pipLayer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);
    pipLayer.opaque = NO;
    pipLayer.backgroundColor = [UIColor clearColor].CGColor;

    [shapeLayer addSublayer:pipLayer];

    return shapeLayer;
}

- (CAShapeLayer*)createKnobWithMarkings
{
    shapeLayer = [CAShapeLayer layer];
    shapeLayer.backgroundColor = [UIColor clearColor].CGColor;
    shapeLayer.opaque = NO;

    pipLayer = nil;
    [self addMarkings];

    return shapeLayer;
}

- (CAShapeLayer*)createRotaryDial
{

    shapeLayer = [CAShapeLayer layer];
    shapeLayer.backgroundColor = [UIColor clearColor].CGColor;
    shapeLayer.opaque = NO;

    [self createDialNumbers];

    return shapeLayer;
}

- (CALayer*)createDialNumbers
{
    if (_mode != IKCModeRotaryDial || _backgroundImage) return nil;

    backgroundLayer.contents = nil;
    for (CALayer* layer in dialMarkings)
    {
        [layer removeFromSuperlayer];
    }
    dialMarkings = [NSMutableArray array];

    int j;
    for (j=0; j<10; ++j) {
        [dialMarkings addObject: [IKCTextLayer layer]];
    }

    [self updateDialNumbers];

    return backgroundLayer;
}

- (CALayer*)createDialStop
{
    float const stopWidth = 0.05;

    // the stop is an isosceles triangle at 4:00 (-M_PI/6) pointing inward radially.

    // the near point is the point nearest the center of the dial, at the edge of the
    // outer tap ring. (see handleTap: for where the 0.586 comes from.)

    float nearX = self.bounds.size.width*0.5 * (1.0 + 0.586 * sqrt(3.0) * 0.5);
    float nearY = self.bounds.size.height*0.5 * (1.0 + 0.586 * 0.5);

    // the opposite edge is tangent to the perimeter of the dial. the width of the far side
    // is stopWidth * self.frame.size.height * 0.5.

    float upperEdgeX = self.bounds.size.width*0.5 * (1.0 + sqrt(3.0) * 0.5 + stopWidth * 0.5);
    float upperEdgeY = self.bounds.size.height*0.5 * (1.0 + 0.5 - stopWidth * sqrt(3.0)*0.5);

    float lowerEdgeX = self.bounds.size.width*0.5 * (1.0 + sqrt(3.0) * 0.5 - stopWidth * 0.5);
    float lowerEdgeY = self.bounds.size.height*0.5 * (1.0 + 0.5 + stopWidth * sqrt(3.0)*0.5);

    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(nearX, nearY)];
    [path addLineToPoint:CGPointMake(lowerEdgeX, lowerEdgeY)];
    [path addLineToPoint:CGPointMake(upperEdgeX, upperEdgeY)];
    [path closePath];

    stopLayer = [CAShapeLayer layer];
    stopLayer.path = path.CGPath;
    stopLayer.position = CGPointMake(self.bounds.origin.x + self.bounds.size.width * 0.5, self.bounds.origin.y + self.bounds.size.height * 0.5);
    stopLayer.bounds = self.bounds;
    stopLayer.backgroundColor = [UIColor clearColor].CGColor;
    stopLayer.opaque = NO;

    return stopLayer;
}

- (CGFloat)titleCircumferenceWithFont:(UIFont*)font
{
    CGFloat max = 0.0;
    for (id titleObject in _titles) {

        CGSize textSize;
        if ([titleObject isKindOfClass:NSAttributedString.class]) {
            NSAttributedString* attributed = (NSAttributedString*)titleObject;
            textSize = attributed.size;
        }
        else if ([titleObject isKindOfClass:NSString.class]) {
            textSize = [(NSString*)titleObject sizeOfTextWithFont:font];
            // NSLog(@"textSize: %f x %f", textSize.width, textSize.height);
        }
        CGFloat width = textSize.width * (1.0 + 2.0 * IKC_TITLE_MARGIN_RATIO);
        max = MAX(max, width);
    }

    return max * _positions;
}

- (CGFloat)fontSizeForTitles
{
    CGFloat styleHeadlineSize = 17.0;

    if ([UIFontDescriptor respondsToSelector:@selector(preferredFontDescriptorWithTextStyle:)]) {
        styleHeadlineSize = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleHeadline].pointSize;
    }
    // NSLog(@"Size of headline style: %f", styleHeadlineSize);

    double angle = _circular ? 2.0*M_PI : _max - _min;

    CGFloat fontSize;
    for (fontSize = 23.0; fontSize >= 7.0; fontSize -= 1.0) {
        if (fontSize > styleHeadlineSize) {
            // don't display anything larger than the current headline size (max. 23 pts.)
            continue;
        }

        // NSLog(@"Looking for font %@ %f", _fontName, fontSize);
        UIFont* font = [self fontWithSize:fontSize];
        if (!font) {
            // Assume it will eventually find one.
            continue;
        }

        CGFloat circumference = [self titleCircumferenceWithFont:font];

        // NSLog(@"With font size %f: circumference %f/%f", fontSize, circumference, angle*self.bounds.size.width*0.25);

        // Empirically, this factor works out well. This allows for a little padding between text segments.
        if (circumference <= angle*self.bounds.size.width*0.4) break;
    }

    return fontSize;
}

@end
