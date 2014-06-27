//
//  DiscreteViewController.swift
//  KnobControlDemo-Swift
//
//  Created by Jimmy Dee on 6/26/14.
//  Copyright (c) 2014 Jimmy Dee. All rights reserved.
//

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
