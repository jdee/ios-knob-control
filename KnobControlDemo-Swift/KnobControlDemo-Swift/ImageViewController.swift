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
protocol ImageChooser {
    func imageChosen(title: String?)
}

/*
 * DEBT: Blech. This is not safe (only works for String[]) and needs work.
 * It would be better to be able to call [NSArray indexOfObject:] or a similar
 * thing in the built-in Array type (which doesn't seem to be there). See ImageViewController.viewWillAppear
 * below.
 */
extension Array {
    func indexOfString(object: String) -> Int? {
        for (index, element) in enumerate(self) {
            let string = element as String
            if string == object {
                return index
            }
        }
        return nil
    }
}

class ImageViewController: UIViewController {

    @IBOutlet var knobHolder : UIView

    var knobControl : IOSKnobControl!

    // DEBT: Shouldn't delegates usually be weak references? But that's not possible with protocols, is it? What's the equivalent to this Obj-C?
    // @property (weak, nonatomic) id<ImageChooser> delegate;
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

        /*
         * This did not work for some reason:
         * let titleArray : NSArray = titles
         * let index = titleArray.indexOfObject(...)
         */

        if let selected = imageTitle {
            if let index = titles.indexOfString(selected) {
                knobControl.positionIndex = index
            }
        }
        else {
            if let index = titles.indexOfString("(none)") {
                knobControl.positionIndex = index
            }
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
