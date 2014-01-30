//
//  IKCViewController.h
//  ios-knob-control
//
//  Created by Jimmy Dee on 1/30/14.
//  Copyright (c) 2014 Jimmy Dee. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface IKCViewController : UIViewController<UITextFieldDelegate>

@property IBOutlet UIView* knobControlView;
@property IBOutlet UILabel* positionLabel;
@property IBOutlet UILabel* indexLabelLabel;
@property IBOutlet UILabel* indexLabel;
@property IBOutlet UISegmentedControl* modeControl;
@property IBOutlet UISegmentedControl* animationControl;
@property IBOutlet UITextField* positionsTextField;
@property IBOutlet UISwitch* circularSwitch;
@property IBOutlet UITextField* minTextField;
@property IBOutlet UITextField* maxTextField;

- (IBAction)modeChanged:(UISegmentedControl*)sender;
- (IBAction)animationChanged:(UISegmentedControl*)sender;
- (IBAction)circularChanged:(UISwitch*)sender;

@end
