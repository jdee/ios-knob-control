/*
Copyright (c) 2013-14, Jimmy Dee
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import UIKit

func % (format: String, val: Float) -> String {
    return String(format: format, val)
}

/*
 * The purpose of the continuous tab is to exercise the knob control in .Continuous mode.
 * There is one primary output field, at the upper right: position. This indicates the angle, in
 * radians, through which the knob has turned from its initial position. There are several
 * further inputs to change the knob's parameters and behavior in continuous mode:
 * - a switch labeled "clockwise" that determines whether the knob considers a positive rotation to be clockwise or counterclockwise
 * - a button labeled "Images" that presents a modal view allowing the user to select images to use with the knob
 * - a segmented control to select which gesture the knob will respond to (1-finger rotation, 2-finger rotation, vertical pan or tap)
 * - a switch labeled "circular" that determines whether the knob can rotate freely all the way around in a circle:
 * -- If this switch is ON, the min and max knob properties are ignored, and the min and max knobs below are disabled
 * -- If this switch is OFF, the position property is constrained to lie between the min and max properties of the knob. The min and
 *    max knob controls are enabled to specify the min and max values of the knob's position property.
 * - min and max knob controls, each with its own output label, reading that control's position as above; the values of these knob positions
 *   are used for the main knob control's min and max properties
 *
 * By setting the circular switch to ON (its default state), you can also exercise the disabled state of the min and max knob controls.
 *
 * Knob controls are always created programmatically and inserted as subviews of placeholder views (usually UIViews, but can be anything).
 */
class ContinuousViewController: BaseViewController, ImageChooser {

    // MARK: Storyboard Outlets
    @IBOutlet var knobHolder : UIView!
    @IBOutlet var positionLabel : UILabel!
    @IBOutlet var clockwiseSwitch : UISwitch!
    @IBOutlet var gestureControl : UISegmentedControl!
    @IBOutlet var circularSwitch : UISwitch!
    @IBOutlet var minHolder : UIView!
    @IBOutlet var maxHolder : UIView!
    @IBOutlet var minLabel : UILabel!
    @IBOutlet var maxLabel : UILabel!

    // MARK: Knob controls
    // Swift allows you to celebrate the IOSKnobControl with three cheers.
    var minControl : IOSKnobControl!
    var maxControl : IOSKnobControl!

    // MARK: Misc. state
    var imageTitle : String?

    // MARK: View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let π = Float(M_PI)

        // Create the knob controls
        knobControl = IOSKnobControl(frame: knobHolder.bounds)
        knobControl.mode = .Continuous
        knobControl.min = -π * 0.5
        knobControl.max = π * 0.5
        knobControl.shadowOpacity = 1.0
        knobControl.clipsToBounds = false
        // NOTE: This is an important optimization when using a custom circular image with a shadow.
        knobControl.knobRadius = 0.475 * knobControl.bounds.size.width

        minControl = IOSKnobControl(frame: minHolder.bounds)
        minControl.mode = .Continuous
        minControl.position = knobControl.min

        maxControl = IOSKnobControl(frame: maxHolder.bounds)
        maxControl.mode = .Continuous
        maxControl.position = knobControl.max

        // Set the colors for the default knob images.
        knobControl.tintColor = UIColor(hue: 0.5, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        minControl.tintColor = UIColor(hue: 0.5, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        maxControl.tintColor = UIColor(hue: 0.5, saturation: 1.0, brightness: 1.0, alpha: 1.0)

        // add knob controls as subviews of their holders and arrange actions for each one in response to .ValueChanged events
        knobControl.addTarget(self, action: "knobPositionChanged:", forControlEvents: .ValueChanged)
        knobHolder.addSubview(knobControl)

        maxControl.addTarget(self, action: "knobPositionChanged:", forControlEvents: .ValueChanged)
        maxHolder.addSubview(maxControl)

        minControl.addTarget(self, action: "knobPositionChanged:", forControlEvents: .ValueChanged)
        minHolder.addSubview(minControl)

        // initialize all remaining state, including the min and max label values
        updateKnobProperties()

        knobPositionChanged(minControl)
        knobPositionChanged(maxControl)

        updateKnobImages()
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if let imageVC = segue.destinationViewController as? ImageViewController {
            // set up image selection for this demo
            imageVC.delegate = self                           // arrange for imageChosen() to be called later
            imageVC.titles = [ "(none)", "knob", "teardrop" ] // image sets from the asset catalog; "(none)" maps to a nil value of imageTitle (in the ImageViewController)
            imageVC.imageTitle = imageTitle                   // retain state; if you go back into the ImageViewController to select another image, the knob there will show your current selection
        }
    }

    // MARK: Action for storyboard outlets
    @IBAction func somethingChanged(sender: AnyObject?) {
        // rather than responding separately to each input, just consult them all whenever any one changes
        updateKnobProperties()
    }

    // MARK: Delegate method
    func imageChosen(title: String?) {
        // store the title selected; will be nil if "(none)" selected
        imageTitle = title

        NSLog("selected image title %@", (title != nil ? title! : "(none)"))

        updateKnobImages()
    }

    // MARK: Action for the knob controls' .ValueChanged events
    func knobPositionChanged(sender: IOSKnobControl) {
        // update the appropriate fields depending on which knob changed
        if sender === knobControl {
            positionLabel.text = "%.02f" % sender.position
        }
        else if sender === minControl {
            knobControl.min = sender.position
            minLabel.text = "%.02f" % knobControl.min
        }
        else if sender === maxControl {
            knobControl.max = sender.position
            maxLabel.text = "%.02f" % knobControl.max
        }
    }

    // MARK: Internal methods
    func updateKnobProperties() {
        // set the gesture according to the segmented control
        switch (gestureControl.selectedSegmentIndex) {
        case 0:
            knobControl.gesture = .OneFingerRotation
        case 1:
            knobControl.gesture = .TwoFingerRotation
        case 2:
            knobControl.gesture = .VerticalPan
        case 3:
            knobControl.gesture = .Tap
        default:
            break
        }
        // many of these properties will be the same for the min and max knobs
        minControl.gesture = knobControl.gesture
        maxControl.gesture = knobControl.gesture

        // set clockwise property
        knobControl.clockwise = clockwiseSwitch.on

        minControl.clockwise = knobControl.clockwise
        maxControl.clockwise = knobControl.clockwise

        // good to do this after changing clockwise to make sure the image is properly positioned
        knobControl.position = knobControl.position
        minControl.position = minControl.position
        maxControl.position = maxControl.position

        // only the main knob control can be circular; if this is true, the min and max knobs are disabled
        knobControl.circular = circularSwitch.on
        minControl.enabled = !knobControl.circular
        maxControl.enabled = minControl.enabled
    }

    func updateKnobImages() {
        if let title = imageTitle {
            /*
             * If an imageTitle is specified, take that image set from the asset catalog and use it for
             * the UIControlState.Normal state. If images are not specified (or are set to nil) for other
             * states, the image for the .Normal state will be used for the knob.
             * If image sets exist beginning with the specified imageTitle and ending with -highlighted or
             * -disabled, those images will be used for the relevant states. If there is no such image set
             * in the asset catalog, the image for that state will be set to nil here.
             * If image sets exist beginning with the specified imageTitle and ending with -foreground or
             * -background, they will be used for the foregroundImage or backgroundImage properties,
             * respectively, of the control. These are mainly used for rotary dial mode and are mostly
             * absent here (nil).
             */

            NSLog("using image title %@", title)
            let normalImage = UIImage(named: title)
            let highlightedImage = UIImage(named: "\(title)-highlighted")
            let disabledImage = UIImage(named: "\(title)-disabled")

            knobControl.setImage(normalImage, forState: .Normal)
            knobControl.setImage(highlightedImage, forState: .Highlighted)
            knobControl.setImage(disabledImage, forState: .Disabled)
            knobControl.backgroundImage = UIImage(named: "\(title)-background")
            knobControl.foregroundImage = UIImage(named: "\(title)-foreground")

            minControl.setImage(normalImage, forState: .Normal)
            minControl.setImage(highlightedImage, forState: .Highlighted)
            minControl.setImage(disabledImage, forState: .Disabled)

            maxControl.setImage(normalImage, forState: .Normal)
            maxControl.setImage(highlightedImage, forState: .Highlighted)
            maxControl.setImage(disabledImage, forState: .Disabled)

            if title == "teardrop" {
                knobControl.knobRadius = 0
            }
        }
        else {
            /*
             * If no imageTitle is specified, set all these things to nil to use the default images
             * generated by the control.
             */
            knobControl.setImage(nil, forState: .Normal)
            knobControl.setImage(nil, forState: .Highlighted)
            knobControl.setImage(nil, forState: .Disabled)

            minControl.setImage(nil, forState: .Normal)
            minControl.setImage(nil, forState: .Highlighted)
            minControl.setImage(nil, forState: .Disabled)

            maxControl.setImage(nil, forState: .Normal)
            maxControl.setImage(nil, forState: .Highlighted)
            maxControl.setImage(nil, forState: .Disabled)

            knobControl.backgroundImage = nil
            knobControl.foregroundImage = nil

            knobControl.knobRadius = 0.475 * knobControl.bounds.size.width
        }

        // use the same foreground/background images (or nil) for the min and max knobs
        minControl.backgroundImage = knobControl.backgroundImage
        minControl.foregroundImage = knobControl.foregroundImage
        maxControl.backgroundImage = knobControl.backgroundImage
        maxControl.foregroundImage = knobControl.foregroundImage
    }

}
