/*
 Copyright (c) 2013-14, Jimmy Dee
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "KCDAppDelegate.h"
#import "KCDImageViewController.h"

@implementation KCDImageViewController {
    NSArray* titles;
    NSInteger currentlySelectedRow;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    /*
     * Might be nice to have it enumerate all the images in the asset catalog, but we add -highlighted and -disabled
     * to the end of each, making that bit more complicated. And this sample app should be simple. It's not hard to
     * change a couple lines of code and rebuild to see a new image. But it's also convenient to be able to change
     * in the app. For now, we'll have to maintain this list by hand.
     */
    titles = @[@"(none)", @"knob", @"teardrop"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    KCDAppDelegate* appDelegate = (KCDAppDelegate*)[UIApplication sharedApplication].delegate;

    currentlySelectedRow = appDelegate.imageTitle ? [titles indexOfObject:appDelegate.imageTitle] : [titles indexOfObject:@"(none)"];
    [_pickerView selectRow:currentlySelectedRow inComponent:0 animated:NO];
}

- (void)done:(id)sender
{
    KCDAppDelegate* appDelegate = (KCDAppDelegate*)[UIApplication sharedApplication].delegate;

    if ([[titles objectAtIndex:currentlySelectedRow] isEqualToString:@"(none)"]) {
        appDelegate.imageTitle = nil;
    }
    else {
        appDelegate.imageTitle = [titles objectAtIndex:currentlySelectedRow];
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIPickerViewDataSource protocol implementation

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return titles.count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [titles objectAtIndex:row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    currentlySelectedRow = row;
}

@end
