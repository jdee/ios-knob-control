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
@class_protocol protocol ImageChooser {
    func imageChosen(title: String?)
}

class ImageViewController: UIViewController {

    @IBOutlet var knobHolder : UIView

    var knobControl : IOSKnobControl!

    /*
     * Hmm. I'd like to make this a weak reference, but the delegate here is a VC that's
     * hidden when this one is presented modally. If I make this weak, I get a crash when
     * calling back the delegate in done() around line 102. This has the potential to create
     * a strong reference loop, but see the remarks above. Not in this case, so meh for now.
     */
    var delegate : ImageChooser?

    var imageTitle : String?
    var titles : String[] = [ "(none)" ]

    override func viewDidLoad() {
        super.viewDidLoad()

        let π = Float(M_PI)

        knobControl = IOSKnobControl(frame: knobHolder.bounds)
        knobControl.mode = .LinearReturn
        knobControl.positions = titles.count
        knobControl.titles = titles
        knobControl.timeScale = 0.5
        knobControl.circular = false
        knobControl.min = -π * 0.5
        knobControl.max = π * 0.5

        var titleColor = UIColor.whiteColor()
        if (knobControl.respondsToSelector("setTintColor:")) {
            knobControl.tintColor = UIColor.yellowColor()
            titleColor = UIColor.blackColor()
        }

        knobControl.setTitleColor(titleColor, forState: .Normal)
        knobControl.setTitleColor(titleColor, forState: .Highlighted)

        knobHolder.addSubview(knobControl)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        let titleArray : NSArray = titles

        if let selected = imageTitle {
            let index = titleArray.indexOfObject(selected)
            knobControl.positionIndex = index
        }
        else {
            let index = titleArray.indexOfObject("(none)")
            knobControl.positionIndex = index
        }
    }

    @IBAction func done(sender: UIButton) {
        var selected = titles[knobControl.positionIndex]
        if selected == "(none)" {
            imageTitle = nil
        }
        else {
            imageTitle = selected
        }

        delegate?.imageChosen(imageTitle)

        dismissViewControllerAnimated(true, completion: nil)
    }

}
