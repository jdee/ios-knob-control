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
 * The feedback demo is the simplest of all the tabs. The purpose is to demonstrate
 * the use of a disabled knob control with a custom image as a dial view. There are
 * two knob controls: one enabled, the other disabled. Whenever the enabled one
 * changes, the disabled one is simply set to the same position. The result is that
 * the bottom knob control does not respond to gestures but just reflects the
 * position of the top knob control, acting like a VU meter. This demo has no
 * configuration controls.
 */
class FeedbackViewController: BaseViewController {

    // MARK: Storyboard Outlets
    @IBOutlet var knobHolder : UIView!
    @IBOutlet var dialHolder : UIView!

    // Two cheers for the IOSKnobControl! Also see the comments in the ContinousViewController
    // on the use of unwrapped optionals
    // MARK: Knob controls
    var dialView : IOSKnobControl!

    // MARK: View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // M_PI is a CDouble, while min and max are CFloat. Might consider making them doubles.
        let π = Float(M_PI)
        let titleColor = UIColor.whiteColor()

        // create the enabled knob control
        knobControl = IOSKnobControl(frame: knobHolder.bounds)
        knobControl.mode = .Continuous
        knobControl.circular = false
        knobControl.min = -π * 0.25
        knobControl.max = π * 0.25

        // Set up colors for the generated image in the top knob
        if (knobControl.respondsToSelector("setTintColor:")) {
            knobControl.tintColor = UIColor.blueColor() // default anyway
        }

        knobControl.setTitleColor(titleColor, forState: .Normal)
        knobControl.setTitleColor(titleColor, forState: .Highlighted)

        // arrange an action for .ValueChanged and add as a subview to its holder
        knobControl.addTarget(self, action: "knobTurned:", forControlEvents: .ValueChanged)

        knobHolder.addSubview(knobControl)

        // Note the convenience constructor, taking the name of an image set from the asset catalog
        dialView = IOSKnobControl(frame: dialHolder.bounds, imageNamed: "needle")
        // these are mostly the same parameters as the first control, except that enabled = false.
        dialView.mode = .Continuous
        dialView.enabled = false
        dialView.circular = false
        dialView.min = knobControl.min
        dialView.max = knobControl.max

        // no need to arrange an action for .ValueChanged. this control will still generate those
        // events when the position is set programmatically, but who cares, since they're precisely
        // the same sequence of events as the first control.
        dialHolder.addSubview(dialView)
    }

    // MARK: Action for the enabled knob control's .ValueChanged events
    func knobTurned(sender : IOSKnobControl) {
        // Here's the meat: Set the dialView's position to the knobControl's position whenever
        // the latter changes.
        dialView.position = sender.position
    }

}
