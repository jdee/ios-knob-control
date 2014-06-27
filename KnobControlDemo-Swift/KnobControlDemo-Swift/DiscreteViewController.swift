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

class DiscreteViewController: UIViewController {

    @IBOutlet var knobHolder : UIView
    @IBOutlet var indexLabel : UILabel
    @IBOutlet var positionLabel : UILabel
    @IBOutlet var clockwiseSwitch : UISwitch
    @IBOutlet var gestureControl : UISegmentedControl
    @IBOutlet var modeControl : UISegmentedControl
    @IBOutlet var timeScaleSlider : UISlider
    @IBOutlet var imageControl : UISegmentedControl

    var knobControl : IOSKnobControl!

    var hexagonImage : UIImage {
    get {
        let suffix = clockwiseSwitch.on ? "cw" : "ccw"
        return UIImage(named: "hexagon-\(suffix)")
    }
    }

    var useHexagonImages : Bool {
    get {
        return imageControl.selectedSegmentIndex > 0
    }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        knobControl = IOSKnobControl(frame: knobHolder.bounds)
        knobControl.mode = .LinearReturn
        knobControl.circular = true

        let titleColor = UIColor.whiteColor()
        if (knobControl.respondsToSelector("setTintColor:")) {
            // iOS 7+
            knobControl.tintColor = UIColor.greenColor()
        }
        knobControl.setTitleColor(titleColor, forState: .Normal)
        knobControl.setTitleColor(titleColor, forState: .Highlighted)

        knobControl.addTarget(self, action: "knobPositionChanged:", forControlEvents: .ValueChanged)
        knobHolder.addSubview(knobControl)

        updateKnobProperties()
    }

    @IBAction func clockwiseChanged(sender: UISwitch) {
        if (useHexagonImages) {
            knobControl.setImage(hexagonImage, forState: .Normal)
        }
        knobControl.clockwise = sender.on
    }

    @IBAction func somethingChanged(sender: AnyObject?) {
        updateKnobProperties()
    }

    func knobPositionChanged(sender: IOSKnobControl) {
        indexLabel.text = String(knobControl.positionIndex)
        positionLabel.text = "%.02f" % knobControl.position
    }

    func updateKnobProperties() {
        knobControl.timeScale = expf(timeScaleSlider.value)

        switch (modeControl.selectedSegmentIndex) {
        case 0:
            knobControl.mode = .LinearReturn
        case 1:
            knobControl.mode = .WheelOfFortune
        default:
            break
        }

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

        knobControl.clockwise = clockwiseSwitch.on

        if (useHexagonImages) {
            knobControl.positions = 6
            knobControl.setImage(hexagonImage, forState: .Normal)
        }
        else {
            knobControl.positions = 12
            knobControl.titles = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ]
            knobControl.setImage(nil, forState: .Normal)
        }

        knobControl.position = knobControl.position
    }

}
