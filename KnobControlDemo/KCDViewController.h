/*
 Copyright (c) 2013-14, Jimmy Dee
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>

@interface KCDViewController : UIViewController

@property IBOutlet UIView* knobControlView;
@property IBOutlet UILabel* positionLabel;
@property IBOutlet UILabel* indexLabelLabel;
@property IBOutlet UILabel* indexLabel;
@property IBOutlet UISegmentedControl* modeControl;
@property IBOutlet UISlider* timeScaleControl;
@property IBOutlet UITextField* positionsTextField;
@property IBOutlet UISwitch* clockwiseSwitch;
@property IBOutlet UISwitch* circularSwitch;
@property IBOutlet UIView* minControlView;
@property IBOutlet UIView* maxControlView;
@property IBOutlet UILabel* minLabel;
@property IBOutlet UILabel* maxLabel;
@property IBOutlet UILabel* minLabelLabel;
@property IBOutlet UILabel* maxLabelLabel;

- (IBAction)modeChanged:(UISegmentedControl*)sender;
- (IBAction)circularChanged:(UISwitch*)sender;
- (IBAction)clockwiseChanged:(UISwitch*)sender;
- (IBAction)timeScaleChanged:(UISlider*)sender;

@end
