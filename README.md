iOS Knob Control
================

This is a generic, reusable knob control you can insert into any application.
You may provide custom knob images or use the customizable default images.
The control animates rotation of the image in response to one of several
configurable gestures from the user. The knob has a number of configurable modes:

- Linear return mode: Like a circular generalization of the UIPickerView control.
  Only certain discrete positions are allowed. The knob rotates
  to follow the user's gesture, but on release returns to an allowed position.
  The time scale for the return animation may be configured as a property of the control.
- Wheel of Fortune mode: Like linear return, except for the animation after the
  user releases the knob. Only a narrow strip between each pair of segments is excluded, like
  the pegs on the rim of a carnival wheel. If the knob was released in one of those
  small excluded strips, it rotates just far enough to exit the excluded strip.
  Otherwise, the knob stays where the user leaves it. This mode is like continuous
  mode except for the behavior in the excluded strips and the availability of the
  positionIndex property.
- Continuous mode: Like a circular generalization of the UISlider control or a
  potentiometer/volume knob. Often used with min. and max. angles, but can also
  be circular. Knob remains wherever the user leaves it and can attain any value
  between the min. and max. equally.
- Rotary dial mode: Like an old rotary telephone dial.

It responds to four different gestures, depending on the value of a property:

- One-finger rotation: Custom gesture recognition. The spot under your finger tracks your touch
  as you rotate the knob.
- Two-finger rotation: The standard iOS two-finger rotation gesture.
- Vertical pan: Drag your finger up or down to increase or decrease the value of the position
  property, respectively.
- Tap: Select a position for the knob or dial a number in rotary dial mode by tapping.

The knob control can be circular, permitting the user to rotate it all the way around,
or it can have a min. and max. angle in continuous and discrete modes.

The control is distributed as a single pair of files (IOSKnobControl.h and IOSKnobControl.m
in this directory), which you can simply drop into your project. Without any externally supplied image,
the control generates appropriate, customizable images in all modes. It can also accept externally
supplied images. You can use any of the images in the demo project here or supply your own.

The knob control and all images must be square. Images will usually be circles or regular polygons, with a
transparent background or a solid one that matches the view behind it. However, the aspect
ratio must be 1:1. The effect of the animation is circular rotation. This only works if the control
is square. You can produce other effects, for example, by partially clipping a square control
or using an oblong background. But the control itself always has to be square.

The control honors the enabled property. That is, if you set enabled to NO, it enters the
UIControlStateDisabled and stops responding to user input. If specified, a disabled image is displayed
instead of the normal image. Even when disabled, the control's position may always be specified
at any time programmatically, with or without animation. With appropriate images, a disabled knob control
may be used as a dial view to display a numeric value.

The KnobControlDemo.xcodeproj sample project can be used to build a simple demo app
to exercise the different modes of the control and provides examples of use. This demo project
uses storyboards and autolayout and so requires iOS 6.0 or greater. The control may easily be used in a
64-bit binary without problem. The demo project is configured to build a 64-bit binary.

The control itself, the IOSKnobControl class, may be compiled down to iOS 5.0, but the demo
project will not build if the iOS Deployment Target is set below 6.0 for reasons that have
nothing to do with the control. The control uses ARC, so it cannot be used below iOS 5.0
without modification. It has not been tested below iOS 6.1, however, and there may be problems
there that have not yet been discovered.

Documentation
-------------

All API documentation can be found in IOSKnobControl.h. Browsable HTML documentation generated from this source is
checked into this repository in the doc/html subdirectory. See doc/html/index.html.

Releases
--------

Stable releases are indicated by tags in the repo (e.g., 1.1.0.2) and notes in the ChangeLog. When in doubt, use the last
stable release tag as opposed to the HEAD revision. If no development has been done since the last release, those may be
the same revision.

Known Issues
------------

Known bugs, planned enhancements and other issues are tracked on [Github](https://github.com/jdee/ios-knob-control/issues).

Media
-----

Some images (the nice ones) courtesy of Mike Calvert (@bloodymonster).

License
=======

The software and media here are available under [The BSD 3-Clause License](http://opensource.org/licenses/BSD-3-Clause):

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