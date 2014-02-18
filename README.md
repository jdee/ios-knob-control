iOS Knob Control
================

This is a generic, reusable knob control you can insert into any application.
You provide any image for the knob. The control animates rotation of the image
in response to a one-finger rotation gesture from the user. The knob has a number
of configurable modes:

- Linear return mode: Like a circular generalization of the UIPickerView control.
  Only certain discrete positions are allowed. The knob rotates
  to follow the user's gesture, but on release returns to an allowed position with
  one of several available animations. The time scale for the return animation may
  be configured as a property of the control.
- Wheel of Fortune mode: Like linear return, except for the animation after the
  user releases the knob. Only a narrow strip between each segment is excluded, like
  the pegs on the rim of a carnival wheel. If the knob was released in one of those
  small excluded strips, it rotates just far enough to exit the excluded strip.
  Otherwise, the knob stays where the user leaves it. This mode is like continuous
  mode except for the behavior in the excluded strips and the availability of the
  positionIndex property.
- Continuous mode: Like a circular generalization of the UISlider control or a
  potentiometer/volume knob. Usually used with min. and max. angles, but can also
  be circular. Knob remains wherever the user leaves it and can attain any value
  between the min. and max. equally.
- Rotary dial mode (not available yet): Like an old rotary telephone dial.

The knob control can be circular, permitting the user to rotate it all the way around,
or it can have a min. and max. angle in continuous and discrete modes.

The control is distributed as a single pair of files (IOSKnobControl.h and IOSKnobControl.m
in this directory), which you can simply drop into your project. You have to provide at
least one image for the knob. You may use any of the images in this project (subject to
the license conditions below) or supply your own.

The KnobControlDemo.xcodeproj sample project can be used to build a simple demo app
to exercise the different modes of the control and provides examples of use. This demo project
uses storyboards and autolayout and so can run on any version of iOS down to 6.0.

The control itself, the IOSKnobControl class, may be compiled down to iOS 5.0, but the demo
project will not build if the iOS Deployment Target is set below 6.0 for reasons that have
nothing to do with the control. The control uses ARC, so it cannot be used below iOS 5.0
without modification.

Known bugs and other issues are tracked on [Github](https://github.com/jdee/ios-knob-control/issues).

---

Notes
-----

- The control now supports a different image for each control state, like the UIButton control.
  It also enters the highlighted mode any time there is a touch down in the control, particularly
  while being dragged. This is analogous to the behavior of the UIButton control, which remains
  in the UIControlStateHighlighted as long as a touch is down in the control's frame.
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
- I got rid of the enumerated animation property, removing the rotary switch animation, which
  is troublesome, and combining the contents of the mode and animation enumerations into a
  single IKCMode enumeration. There are four defined values: IKCMLinearReturn, IKCMWheelOfFortune,
  IKCMContinuous and IKCMRotaryDial. Since rotary dial is being postponed until after the
  initial release, the first three now appear as options in a single segmented control
  in the demo app. In addition, there is now a scale property that specifies the time scale of
  the return animations for linear return and WoF modes. That is mapped to the value of a slider
  in the demo app. Slide to the left to reduce the time scale and speed up the animations. Slide to
  the right to include the time scale and slow animations.

License
=======

Software
--------
This software is available under [The BSD 3-Clause License](http://opensource.org/licenses/BSD-3-Clause):

```
Copyright (c) 2013-14, Jimmy Dee
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted
provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions
   and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions
   and the following disclaimer in the documentation and/or other materials provided with the
   distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse
   or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
    IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
    FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
    CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
    OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
```

Artwork
-------
(Placeholder.)
```
All images Copyright (c) 2014, Mike Calvert
All rights reserved.
```