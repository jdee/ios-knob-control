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

- The rotary switch animation is not done. If you choose that option in the demo app, the
  results are unpredictable. I just know it isn’t done and won’t work. The idea there is that
  the knob should animate abruptly from one discrete position to the next, like an old-style
  channel changer on a TV.
- The min. and max. are a bit goofy. I have to come to closure on allowed ranges for angles.
  It’s easier to enforce a continuous range, and I want the default value of 0 always to be
  legal, so the min has to be less than 0, and the max has to be greater than 0. But the knob
  reads out from 0 to 2pi (6.28). Here’s a recipe for success: Set the knob to continuous mode.
  Set the circular switch to OFF and then enter -2 for the min and 2 for the max. The min.
  will be at 4.28 (2pi - 2), and the max at 2.00.
- Not all combinations of parameters work at the moment in the demo app, but many of them
  work if you do it yourself. The reason is that I always use the same hexagonal knob image
  in the demo app in discrete mode. That could be confusing with a min. and max., so I
  disabled the circular switch and the min. and max. fields in discrete mode. But the
  control should work with that combination, if you have an image that makes sense for it.
  You can certainly go into the sample project and comment out all use of the
  imageNamed:@"hexagon" and make sure to always use imageNamed:@"knob", enable all the
  controls and observe the behavior with just about any combination of parameters. Meaning
  and usage is explained for everything in the IOSKnobControl.h file.


Copyright (C) 2014 Jimmy Dee. All rights reserved.
