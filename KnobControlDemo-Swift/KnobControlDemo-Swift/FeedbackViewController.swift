//
//  FirstViewController.swift
//  KnobControlDemo-Swift
//
//  Created by Jimmy Dee on 6/25/14.
//  Copyright (c) 2014 Jimmy Dee. All rights reserved.
//

import UIKit

class FeedbackViewController: UIViewController {

    @IBOutlet var knobHolder : UIView
    @IBOutlet var dialHolder : UIView

    var knobControl : IOSKnobControl!
    var dialControl : IOSKnobControl!
                            
    override func viewDidLoad() {
        super.viewDidLoad()

        let π = CFloat(M_PI)
        let titleColor = UIColor.whiteColor()

        knobControl = IOSKnobControl(frame: knobHolder.bounds)
        knobControl.mode = .IKCMContinuous
        knobControl.circular = false
        knobControl.min = -π * 0.25
        knobControl.max = π * 0.25

        knobControl.setTitleColor(titleColor, forState: .Normal)
        knobControl.setTitleColor(titleColor, forState: .Highlighted)
        knobControl.addTarget(self, action:"knobTurned:", forControlEvents:.ValueChanged)

        knobHolder.addSubview(knobControl)

        dialControl = IOSKnobControl(frame: dialHolder.bounds, imageNamed: "needle")
        dialControl.mode = .IKCMContinuous
        dialControl.circular = false
        dialControl.min = knobControl.min
        dialControl.max = knobControl.max

        dialHolder.addSubview(dialControl)
    }

    func knobTurned(sender : IOSKnobControl) {
        dialControl.position = sender.position
    }

}
