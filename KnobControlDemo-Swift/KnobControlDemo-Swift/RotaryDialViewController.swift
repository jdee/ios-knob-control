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
 * This demo exercises the knob control's .RotaryDial mode. The size of the control
 * limits the size of the finger holes in the control, so in this mode it's recommended
 * to render the control at a large size. In fact, in rotary dial mode, the control
 * enforces a minimum size for this reason.
 * There are two configuration controls as input, directly below the control:
 * - a segmented control to select the gesture; only one-finger rotation and tap are supported in this mode
 * - a time-scale slider for the return animation; this affects the speed of the animation after you release the control
 * Below these are the only output field, a label that displays the number dialed, and a button labeled Images
 * that allows the user to use the dial with a set of images. The default dial images are rendered by the control as in
 * the other modes.
 */
class RotaryDialViewController: BaseViewController, ImageChooser {

    // MARK: Storyboard Outlets
    @IBOutlet var knobHolder : UIView!
    @IBOutlet var numberLabel : UILabel!

    // MARK: Other state
    // Place to accumulate the number dialed
    var numberDialed = ""

    // State retention: stores the user's last selection from the ImageViewController
    var imageTitle : String?

    // MARK: View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the knob control
        knobControl = IOSKnobControl(frame: knobHolder.bounds)
        knobControl.mode = .RotaryDial
        knobControl.gesture = .OneFingerRotation
        knobControl.shadowOpacity = 0.7
        knobControl.clipsToBounds = false

        // knobControl.fontName = "CourierNewPS-BoldMT"
        // knobControl.fontName = "Verdana-Bold"
        // knobControl.fontName = "Georgia-Bold"
        // knobControl.fontName = "TimesNewRomanPS-BoldMT"
        knobControl.fontName = "AvenirNext-Bold"
        // knobControl.fontName = "TrebuchetMS-Bold"

        //* color specification
        let normalColor = UIColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 0.7)
        let highlightedColor = UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 0.7)
        let titleColor = UIColor(red: 0.0, green: 0.3, blue: 0.0, alpha: 1.0)

        knobControl.setFillColor(normalColor, forState: .Normal)
        knobControl.setFillColor(highlightedColor, forState: .Highlighted)
        knobControl.setTitleColor(titleColor, forState: .Normal)
        // */

        // arrange to be called back when the user dials
        knobControl.addTarget(self, action: "dialed:", forControlEvents: .ValueChanged)

        // add the control to its holder
        knobHolder.addSubview(knobControl)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        // reset the number dialed each time the view appears
        // (number dialed) is displayed in the label instead of a blank string
        numberDialed = ""
        numberLabel.text = "(number dialed)"
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if let imageVC = segue.destinationViewController as? ImageViewController {
            imageVC.delegate = self                    // arrange for imageChosen() to be called later
            imageVC.titles = [ "(none)", "telephone" ] // specify the images to use
            imageVC.imageTitle = imageTitle            // pass in the user's last choice or nil for "(none)"
        }
    }

    // MARK: Image chooser delegate method
    func imageChosen(title: String?) {
        // save the user's choice and update the knob images
        imageTitle = title
        updateKnobImages()
    }

    // MARK: Action for the knob control's .ValueChanged events
    func dialed(sender: IOSKnobControl) {
        // append the last digit dialed and display
        numberDialed = "\(numberDialed)\(sender.positionIndex)"
        numberLabel.text = numberDialed
    }

    // MARK: Actions for storyboard outlets
    @IBAction func gestureChanged(sender: UISegmentedControl) {
        // change the gesture (1-finger rotation and tap only in rotary dial mode)

        switch (sender.selectedSegmentIndex) {
        case 0:
            knobControl.gesture = .OneFingerRotation
        case 1:
            knobControl.gesture = .Tap
        default:
            break
        }
    }

    @IBAction func timescaleChanged(sender: UISlider) {
        /*
         * Using exponentiation avoids compressing the scale below 1.0. The
         * slider starts at 0 in middle and ranges from -1 to 1, so the
         * time scale can range from 1/e to e, and defaults to 1.
         */
        knobControl.timeScale = expf(sender.value)
    }

    // MARK: Internal methods
    func updateKnobImages() {
        if let title = imageTitle {
            /*
             * As in the ContinuousViewController, if an image set exists starting with the selected title
             * and ending in -highlighted or -disabled, it is used for that state.
             * Image sets ending in -background or -foreground, if any, are used for the background and
             * foreground images.
             */
            knobControl.setImage(UIImage(named: title), forState: .Normal)
            knobControl.setImage(UIImage(named: "\(title)-highlighted"), forState: .Highlighted)
            knobControl.setImage(UIImage(named: "\(title)-disabled"), forState: .Disabled)
            knobControl.backgroundImage = UIImage(named: "\(title)-background")
            knobControl.foregroundImage = UIImage(named: "\(title)-foreground")
            knobControl.foregroundLayerShadowPath = dialStopShadowPath
        }
        else {
            // use the default, generated images if (none) selected
            knobControl.setImage(nil, forState: .Normal)
            knobControl.setImage(nil, forState: .Highlighted)
            knobControl.setImage(nil, forState: .Disabled)
            knobControl.backgroundImage = nil
            knobControl.foregroundImage = nil
        }
    }

    private var dialStopShadowPath: UIBezierPath {
        get {
            let stopWidth: CGFloat = 0.05

            // the stop is an isosceles triangle at 4:00 (-M_PI/6) pointing inward radially.

            // the near point is the point nearest the center of the dial, at the edge of the
            // outer tap ring. (see handleTap: for where the 0.586 comes from.)

            let width = knobControl.bounds.size.width
            let height = knobControl.bounds.size.height

            let nearX = width * 0.5 * (1.0 + 0.586 * sqrt(3.0) * 0.5)
            let nearY = height * 0.5 * (1.0 + 0.586 * 0.5)

            // the opposite edge is tangent to the perimeter of the dial. the width of the far side
            // is stopWidth * self.frame.size.height * 0.5.

            let upperEdgeX = width * 0.5 * (1.0 + sqrt(3.0) * 0.5 + stopWidth * 0.5)
            let upperEdgeY = height * 0.5 * (1.0 + 0.5 - stopWidth * sqrt(3.0) * 0.5)

            let lowerEdgeX = width * 0.5 * (1.0 + sqrt(3.0) * 0.5 - stopWidth * 0.5)
            let lowerEdgeY = height * 0.5 * (1.0 + 0.5 + stopWidth * sqrt(3.0) * 0.5)

            let path = UIBezierPath()
            path.moveToPoint(CGPointMake(nearX, nearY))
            path.addLineToPoint(CGPointMake(lowerEdgeX, lowerEdgeY))
            path.addLineToPoint(CGPointMake(upperEdgeX, upperEdgeY))
            path.closePath()
            return path
        }
    }

}
