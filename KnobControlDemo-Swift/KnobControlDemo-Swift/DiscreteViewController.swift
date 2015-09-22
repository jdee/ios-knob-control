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

/*
 * The purpose of the discrete demo is to exercise the knob control in the discrete
 * modes .LinearReturn and .WheelOfFortune. A segmented control selects between these
 * modes. This view includes a single knob control with two output fields in the upper
 * right: position and index. The index field displays the value of the knob's positionIndex
 * property, which is not available in .Continous or .RotaryDial mode. In addition, the
 * following controls configure the knob control's behavior:
 * - a switch labeled "clockwise" that determines whether the knob considers a positive rotation to be clockwise or counterclockwise
 * - a segmented control to select which gesture the knob will respond to (1-finger rotation, 2-finger rotation, vertical pan or tap)
 * - a slider labeled "time scale" that specifies the timeScale property of the knob control (for return animations, which only occur in discrete modes)
 * - a segmented control to select between two different sets of demo images
 * -- months: the control generates the knob image from the knob's titles property; the user can select any month from the knob
 * -- hexagon: the control uses one of two image sets from the asset catalog, each a hexagon with index values printed around the sides; changing the
 *    clockwise setting switches to a different image with numbers rendered in the opposite direction
 */
class DiscreteViewController: BaseViewController {

    // MARK: Storyboard Outlets
    @IBOutlet var knobHolder : UIView!
    @IBOutlet var indexLabel : UILabel!
    @IBOutlet var positionLabel : UILabel!
    @IBOutlet var clockwiseSwitch : UISwitch!
    @IBOutlet var gestureControl : UISegmentedControl!
    @IBOutlet var modeControl : UISegmentedControl!
    @IBOutlet var timeScaleSlider : UISlider!
    @IBOutlet var imageControl : UISegmentedControl!

    // MARK: computed properties for convenience when working with the hexagon demo
    var hexagonImage : UIImage {
    get {
        let suffix = clockwiseSwitch.on ? "cw" : "ccw"
        return UIImage(named: "hexagon-\(suffix)")!
    }
    }

    var useHexagonImages : Bool {
    get {
        return imageControl.selectedSegmentIndex > 0
    }
    }

    // MARK: View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the knob control
        knobControl = IOSKnobControl(frame: knobHolder.bounds)
        knobControl.circular = true

        // knobControl.fontName = "CourierNewPS-BoldMT"
        knobControl.fontName = "Verdana-Bold"
        // knobControl.fontName = "Georgia-Bold"
        // knobControl.fontName = "TimesNewRomanPS-BoldMT"
        // knobControl.fontName = "AvenirNext-Bold"
        // knobControl.fontName = "TrebuchetMS-Bold"

        knobControl.setFillColor(UIColor.lightGrayColor(), forState: .Normal)
        knobControl.setFillColor(UIColor(red:0.9, green:0.9, blue:0.9, alpha:1.0), forState: .Highlighted)

        // specify an action for the .ValueChanged event and add as a subview to the knobHolder UIView
        knobControl.addTarget(self, action: "knobPositionChanged:", forControlEvents: .ValueChanged)
        knobHolder.addSubview(knobControl)

        knobPositionChanged(knobControl)

        // initialize all other properties based on initial control values
        updateKnobProperties()
    }

    // MARK: Actions for storyboard outlets
    @IBAction func clockwiseChanged(sender: UISwitch) {
        // use the computed properties from above here
        if (useHexagonImages) {
            knobControl.setImage(hexagonImage, forState: .Normal)
        }
        knobControl.clockwise = sender.on
    }

    @IBAction func somethingChanged(sender: AnyObject?) {
        // everything but the clockwise switch comes through here
        updateKnobProperties()
    }

    // MARK: Action for the knob control's .ValueChanged events
    func knobPositionChanged(sender: IOSKnobControl) {
        // display both the position and positionIndex properties
        indexLabel.text = String(knobControl.positionIndex)
        positionLabel.text = "%.02f" % knobControl.position
    }

    // MARK: Internal methods
    func updateKnobProperties() {
        /*
         * Using exponentiation avoids compressing the scale below 1.0. The
         * slider starts at 0 in middle and ranges from -1 to 1, so the
         * time scale can range from 1/e to e, and defaults to 1.
         */
        knobControl.timeScale = expf(timeScaleSlider.value)

        // Set the .mode property of the knob control
        switch (modeControl.selectedSegmentIndex) {
        case 0:
            knobControl.mode = .LinearReturn
        case 1:
            knobControl.mode = .WheelOfFortune
        default:
            break
        }

        // Configure the gesture to use
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

        // clockwise or counterclockwise
        knobControl.clockwise = clockwiseSwitch.on

        // Make use of computed props again to switch between the two demos
        if (useHexagonImages) {
            knobControl.positions = 6
            knobControl.setImage(hexagonImage, forState: .Normal)
        }
        else {
            let titles = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ]

            let font = UIFont(name: knobControl.fontName, size: 14.0)
            let italicFontDesc = UIFontDescriptor(name: "Verdana-BoldItalic", size: 14.0)
            let italicFont = UIFont(descriptor: italicFontDesc, size: 0.0)

            var attribTitles = [NSAttributedString]()

            for (index, title) in titles.enumerate() {
                let textColor = UIColor(hue:CGFloat(index)/CGFloat(titles.count), saturation:1.0, brightness:1.0, alpha:1.0)
                let isOdd: Bool = index % 2 != 0
                let currentFont = isOdd ? italicFont : font
 
                let attributed = NSAttributedString(string: title, attributes: [NSFontAttributeName: currentFont!, NSForegroundColorAttributeName: textColor])
                attribTitles.append(attributed)
            }
            knobControl.titles = attribTitles

            knobControl.positions = 12
            knobControl.setImage(nil, forState: .Normal)
        }

        // Good idea to do this to make the knob reset itself after changing certain params.
        knobControl.position = knobControl.position
    }
}
