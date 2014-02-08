iOS Knob Control
================

This is a generic, reusable knob control you can insert into any application.
You provide any image for the knob. The control animates rotation of the image
in response to a one-finger rotation gesture from the user. The knob has a number
of configurable modes and animations:

- Continuous mode: Like a circular generalization of the UISlider control or a
  potentiometer/volume knob. Usually used with min. and max. angles, but can also
  be circular. Knob remains wherever the user leaves it and can attain any value
  between the min. and max. equally.
- Discrete mode: Like a circular generalization of the UIPickerView control.
  Only certain discrete positions are allowed. The knob rotates
  to follow the user's gesture, but on release returns to an allowed position with
  one of several available animations.
- Rotary dial mode (not available yet): Like an old-school telephone dial.

The knob control can be circular, permitting the user to rotate it all the way around,
or it can have a min. and max. angle in continuous and discrete modes.

The control is distributed as a single pair of files (IOSKnobControl.h and IOSKnobControl.m in this directory), which you can simply
drop into your project.

The ios-knob-control.xcodeproj sample project can be used to build a simple demo app
to exercise the different modes of the control and provides an example of use.

---

Notes
-----

- The rotary switch animation is not done. The intention of this animation is that if you rotate
  the knob with your finger a small distance away from an allowed position, it will snap to the
  next or previous position very quickly, even before the gesture is complete. That complicates
  matters. This animation might be removed. At any rate, it's currently buggy.
- I finally changed all angular parameters (position, min, max, etc.) to be in (-M_PI, M_PI].
  The min and max parameters are not currently validated, but they should be in that range.
- Not all combinations of parameters work at the moment in the demo app, but many of them
  work if you do it yourself. The reason is that I always use the same hexagonal knob image
  in the demo app in discrete mode. That could be confusing with a min. and max., so I
  disabled the circular switch and the min. and max. fields in discrete mode. But the
  control should work with that combination, if you have an image that makes sense for it.
  You can certainly go into the sample project and comment out all use of the
  imageNamed:@"hexagon" and make sure to always use imageNamed:@"knob", enable all the
  controls and observe the behavior with just about any combination of parameters. Meaning
  and usage is explained for everything in the IOSKnobControl.h file.
- The new round knob images are courtesy of Mike Calvert (@bloodymonster).
- The text inputs for min and max have been replaced with--you guessed it--knobs. This gives
  a further example of use and a visual representation of the min and max for those not
  used to thinking in radians.
- There is one known issue involving the min and max. In order to make 0 always be an
  acceptable value, the min and max should be limited to [-M_PI,0] and [0,M_PI],
  respectively. This is not currently enforced by the knob control itself, though the
  smaller min and max knobs respect those ranges in the sample app. However, it is possible
  to set these values close enough together that the user can effectively jump the min/max
  divide. In particular, if min == -M_PI and max == M_PI, in effect circular == YES. It
  should, in that case, be possible to turn the knob to any position, but only by going in
  the right direction, without crossing the space > max and < min. This will be addressed
  in the near future.

Copyright (C) 2014 Jimmy Dee. All rights reserved.
