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

/**
 * Delegate protocol for ImageViewController
 */
// https://devforums.apple.com/message/985898#985898
/*
 * The real issue here is that a protocol can be used for a class or a struct, so
 * a protocol variable may be a reference (to a class) or a value type (copy of a struct).
 * Using @class_protocol means it cannot be used with structs, so the delegate property
 * of ImageViewController can be marked weak. A strong reference loop is not a practical 
 * concern here; the only time the Rotary Dial or Continuous view controller sees this
 * ImageViewController is in prepareForSegue(, sender:), where the association is made.
 * Since the other VC does not retain a strong reference to this one, there's no loop.
 * But this is good practice.
 */
protocol ImageChooser : class {
    // called when the user taps the Choose button
    // title is the string selected from the list or nil if "(none)" was selected
    func imageChosen(title: String?)
}

/*
 * This View Controller is presented modally by the continuous and rotary dial views when
 * the Images button is tapped in either one, to allow the user to see yet another knob
 * control and select a set of images to use for the control(s) in that demo. The two demos
 * have different image requirements, so the list in each case is different and specified
 * by setting the titles property of the destinationViewController in the other view
 * controller's prepareForSegue(,sender:) method. The titles are used to construct a discrete
 * knob in .LinearReturn mode. The user selects an image set by rotating that name to the
 * top, where it is mest legible. Then she taps the Choose button, the model view controller
 * disappears, and the main view controller's imageChosen() method is called.
 */
class ImageViewController: BaseViewController {

    // MARK: Storyboard Outlet
    @IBOutlet var knobHolder : UIView!

    /*
     * Hmm. I'd like to make this a weak reference, but the delegate here is a VC that's
     * hidden when this one is presented modally. If I make this weak, I get a crash when
     * calling back the delegate in done() around line 102. This has the potential to create
     * a strong reference loop, but see the remarks above. Not in this case, so meh for now.
     */
    // MARK: Image chooser delegate
    var delegate : ImageChooser?

    // MARK: Other state
    // state retention: if set, the specified imageTitle will be rotated to the top when the
    // view is first displayed, reflecting the user's previous choice.
    var imageTitle : String?

    // this property is assigned by the other VC in prepareForSegue(, sender:)
    var titles : [String] = [ "(none)" ]

    // MARK: View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let π = Float(M_PI)

        // Create the knob Control
        knobControl = IOSKnobControl(frame: knobHolder.bounds)
        knobControl.mode = .LinearReturn
        knobControl.positions = UInt(titles.count) // never inferred from titles; if they don't match, positions wins, and empty spaces are filled with index numbers (0, 1, ...)
        knobControl.titles = titles
        knobControl.timeScale = 0.5
        knobControl.circular = false
        knobControl.min = -π * 0.5
        knobControl.max = π * 0.5

        // knobControl.fontName = "CourierNewPS-BoldMT"
        // knobControl.fontName = "Verdana-Bold"
        // knobControl.fontName = "Georgia-Bold"
        // knobControl.fontName = "TimesNewRomanPS-BoldMT"
        // knobControl.fontName = "AvenirNext-Bold"
        knobControl.fontName = "TrebuchetMS-Bold"

        // color set up
        let titleColor = UIColor.blackColor()
        knobControl.tintColor = UIColor.yellowColor()

        knobControl.setTitleColor(titleColor, forState: .Normal)

        // add as a subview to the holder
        knobHolder.addSubview(knobControl)

        // note that we don't care here when the knob is rotated; we don't do anything in response in the app code.
        // only in done() when the user taps Choose do we consult the knob's positionIndex to find the chosen title
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        // Set the knob to the last selected positionIndex.
        // Use [NSArray indexOfObject:] over a bridge
        let titleArray : NSArray = titles

        if let selected = imageTitle {
            let index = titleArray.indexOfObject(selected)
            knobControl.positionIndex = index
        }
        else {
            // note that the nil/unset value of imageTitle is mapped to the "(none)" entry
            let index = titleArray.indexOfObject("(none)")
            knobControl.positionIndex = index
        }
    }

    // MARK: Action for storyboard outlet
    @IBAction func done(sender: UIButton) {
        // The user has spoken

        // This looks enough like Obj-C at a glance to make me nervous.
        let selected = titles[knobControl.positionIndex]
        if selected == "(none)" {
            // note that the nil/unset value of imageTitle is mapped to the "(none)" entry
            imageTitle = nil
        }
        else {
            imageTitle = selected
        }

        // if no delegate, this is a no-op
        // this crashes if I make the delegate a weak ref though atm
        delegate?.imageChosen(imageTitle)

        // Say good night, Gracie.
        dismissViewControllerAnimated(true, completion: nil)
    }

}
