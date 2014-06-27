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

// convenience for formatting
@infix func % (format: String, val: Float) -> String {
    return String(format: format, val)
}

class ContinuousViewController: UIViewController, ImageChooser {

    @IBOutlet var knobHolder : UIView
    @IBOutlet var positionLabel : UILabel

    var knobControl : IOSKnobControl!
    var imageTitle : String?

    override func viewDidLoad() {
        super.viewDidLoad()

        knobControl = IOSKnobControl(frame: knobHolder.bounds)
        knobControl.mode = .Continuous
        knobControl.circular = true

        if (knobControl.respondsToSelector("setTintColor:")) {
            // iOS 7+
            knobControl.tintColor = UIColor(hue: 0.5, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        }
        else {
            // can still customize piecemeal below iOS 7 (or in iOS 7+ instead of just using the tintColor)
            let titleColor = UIColor.whiteColor()
            knobControl.setTitleColor(titleColor, forState: .Normal)
            knobControl.setTitleColor(titleColor, forState: .Highlighted)
        }

        knobControl.addTarget(self, action: "knobPositionChanged:", forControlEvents: .ValueChanged)
        knobHolder.addSubview(knobControl)
    }

    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        if let imageVC = segue.destinationViewController as? ImageViewController {
            imageVC.delegate = self
            imageVC.titles = [ "(none)", "knob", "teardrop" ]
            imageVC.imageTitle = imageTitle
        }
    }

    func imageChosen(title: String?) {
        imageTitle = title

        NSLog("selected image title %@", (title ? title! : "(none)"))

        updateKnobImages()
    }

    func knobPositionChanged(sender: IOSKnobControl) {
        positionLabel.text = "%.02f" % sender.position
    }

    func updateKnobImages() {
        if let title = imageTitle {
            NSLog("using image title %@", title)
            knobControl.setImage(UIImage(named: title), forState: .Normal)
            knobControl.setImage(UIImage(named: "\(title)-highlighted"), forState: .Highlighted)
            knobControl.setImage(UIImage(named: "\(title)-disabled"), forState: .Disabled)
            knobControl.backgroundImage = UIImage(named: "\(title)-background")
            knobControl.foregroundImage = UIImage(named: "\(title)-foreground")
        }
        else {
            knobControl.setImage(nil, forState: .Normal)
            knobControl.setImage(nil, forState: .Highlighted)
            knobControl.setImage(nil, forState: .Disabled)
            knobControl.backgroundImage = nil
            knobControl.foregroundImage = nil
        }
    }

}
