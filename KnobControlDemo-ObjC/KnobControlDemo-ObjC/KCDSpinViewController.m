/*
 Copyright (c) 2013-14, Jimmy Dee
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <MediaPlayer/MediaPlayer.h>

#import "IOSKnobControl.h"
#import "KCDAppDelegate.h"
#import "KCDSpinViewController.h"

#define IKC_33RPM_ANGULAR_VELOCITY (10.0 * M_PI / 9.0)

@interface KCDSpinViewController ()
@property (nonatomic) double normalizedPlaybackTime;
@property (nonatomic) KCDAppDelegate* appDelegate;
@end

@implementation KCDSpinViewController {
    IOSKnobControl* knobControl;
    CADisplayLink* displayLink;
    MPMusicPlayerController* musicPlayer;
    MPMediaItemCollection* mediaCollection;
    MPVolumeView* volumeView;
    UIView* loadingView;

    double trackLength, currentPlaybackTime;
    BOOL touchIsDown;
}

@dynamic normalizedPlaybackTime;

- (double)normalizedPlaybackTime
{
    /* Swift:
     var playbackTime = currentPlaybackTime % trackLength
     if playbackTime < 0 {
     playbackTime += trackLength
     }
     return playbackTime
     */

    double completeLoops = 0.0;
    double playbackTime = modf(currentPlaybackTime/trackLength, &completeLoops) * trackLength;
    if (playbackTime < 0.0) {
        playbackTime += trackLength;
    }
    return playbackTime;
}

- (KCDAppDelegate *)appDelegate
{
    return [UIApplication sharedApplication].delegate;
}

#pragma mark - Object lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    trackLength = currentPlaybackTime = 0.0;
    touchIsDown = NO;

    [self createKnobControl];
    [self createDisplayLink];
    [self createMusicPlayer];
    [self createLoadingView];

    self.appDelegate.foregrounder = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (musicPlayer.nowPlayingItem) {
        [musicPlayer play];
        displayLink.paused = NO;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (musicPlayer.nowPlayingItem) {
        [musicPlayer pause];
        displayLink.paused = YES;
    }
}

- (void)selectTrack:(UIButton *)sender
{
    [self addLoadingView];

    MPMediaPickerController* mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];
    mediaPicker.allowsPickingMultipleItems = NO;
    mediaPicker.delegate = self;
    mediaPicker.prompt = @"Select a track";
    [self presentViewController:mediaPicker animated:YES completion:nil];
}

- (void)resumeFromBackground:(KCDAppDelegate *)theAppDelegate
{
    /*
     * The MPMusicPlayerController dumps the user's selection when the app is backgrounded.
     * This is OK for this demo app, but reset the view to its state when no track is
     * selected, prompting the user to select again.
     */
    knobControl.position = 0.0;
    knobControl.enabled = NO;
    currentPlaybackTime = 0.0;
    trackLength = 0.0;
    [self updateProgress];
    [self updateLabel:_trackLengthLabel withTime:trackLength];
    [_iTunesButton setTitle:@"select iTunes track" forState:UIControlStateNormal];
}

- (void)knobRotated:(IOSKnobControl*)sender
{
    /*
     * Just update this ivar while the knob is being rotated, and adjust the progress view to reflect the same
     * value. Only assign this to the musicPlayer's currentPlaybackTime property once play resumes when the
     * touch comes up. See animateKnob() above.
     */
    currentPlaybackTime = sender.position / IKC_33RPM_ANGULAR_VELOCITY;
    [self updateProgress];
}

- (void)animateKnob:(CADisplayLink*)link
{
    // cheap way of detecting touch down/up events in this unusual scenario
    if (!touchIsDown && knobControl.highlighted) {
        // pause whenever a touch goes down
        [musicPlayer pause];
        currentPlaybackTime = musicPlayer.currentPlaybackTime;
    }
    else if (touchIsDown && !knobControl.highlighted) {
        // resume whenever the touch comes up
        musicPlayer.currentPlaybackTime = self.normalizedPlaybackTime;
        [musicPlayer play];
    }
    touchIsDown = knobControl.highlighted;

    // .Stopped shouldn't happen if musicPlayer.repeatMode == .All
    if (touchIsDown || !musicPlayer.nowPlayingItem || musicPlayer.playbackState == MPMoviePlaybackStateStopped) {
        // if the user is interacting with the knob (or nothing is selected), don't animate it
        return;
    }

    /*
     * If the user is not interacting with the knob, update the currentPlaybackTime, which can
     * be modified by turning the knob (see knobRotated: below), and adjust the position of
     * both the knob and the progress view to reflect the new value.
     */

    currentPlaybackTime = musicPlayer.currentPlaybackTime;

    // link.duration * link.frameInterval is how long it's been since the last invocation of
    // this callback, so this is another alternative:
    // knobControl.position += Float(link.duration) * Float(link.frameInterval) * angularMomentum

    // but this is simpler, given the way the knob control and music player work
    knobControl.position = currentPlaybackTime * IKC_33RPM_ANGULAR_VELOCITY;

    [self updateProgress];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [loadingView removeFromSuperview];

    knobControl.enabled = YES;

    mediaCollection = mediaItemCollection;

    [musicPlayer setQueueWithItemCollection:mediaCollection];
    [musicPlayer play];
    displayLink.paused = NO;

    trackLength = ((NSNumber*)[musicPlayer.nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration]).doubleValue;
    NSLog(@"Selected item duration is %f", trackLength);
    [self updateLabel:_trackLengthLabel withTime:trackLength];

    NSString* title = (NSString*)[musicPlayer.nowPlayingItem valueForProperty:MPMediaItemPropertyTitle];
    NSString* artist = (NSString*)[musicPlayer.nowPlayingItem valueForProperty:MPMediaItemPropertyArtist];
    [_iTunesButton setTitle:[NSString stringWithFormat:@"%@ - %@", artist, title] forState:UIControlStateNormal];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [loadingView removeFromSuperview];
}

- (void)createKnobControl
{
    knobControl = [[IOSKnobControl alloc] initWithFrame:_knobHolder.bounds imageNamed:@"disc"];
    knobControl.mode = IKCModeContinuous;
    knobControl.clockwise = YES;
    knobControl.circular = YES;
    knobControl.normalized = NO;
    knobControl.enabled = NO;
    [knobControl addTarget:self action:@selector(knobRotated:) forControlEvents:UIControlEventValueChanged];
    [knobControl setImage:[UIImage imageNamed:@"disc-disabled"] forState:UIControlStateDisabled];
    [_knobHolder addSubview:knobControl];
}

- (void)createDisplayLink
{
    // CADisplayLink from CoreAnimation/QuartzCore calls the supplied selector on the main thread
    // whenever it's time to prepare a frame for display. It includes a lot of conveniences, like
    // easy scaling of the frame rate and automatic pause on background.
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(animateKnob:)];
    displayLink.frameInterval = 3; // 20 fps
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)createMusicPlayer
{
    musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
    musicPlayer.repeatMode = MPMusicRepeatModeAll;

    volumeView = [[MPVolumeView alloc] initWithFrame:_volumeViewHolder.bounds];
    [_volumeViewHolder addSubview:volumeView];
}

- (void)createLoadingView
{
    // The iTunes library load can take a little time, which can be confusing, so we can provide some feedback and disable
    // the whole view by adding a transparent view on top with an activity spinner. This is added as a subview of the main
    // view, on top of everything else, in selectTrack(), when the user taps the button. This is kind of hard to do in the
    // storyboard.
    // This could be the reason for the delay: <MPRemoteMediaPickerController: 0x14e723e0> timed out waiting for fence barrier from com.apple.MusicUIService
    loadingView = [[UIView alloc] initWithFrame:self.view.bounds];
    loadingView.opaque = NO;
    loadingView.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];

    UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [spinner startAnimating];
    CGRect frame = spinner.frame;
    frame.origin.x = (self.view.bounds.size.width - frame.size.width) * 0.5;
    frame.origin.y = (self.view.bounds.size.height - frame.size.height) * 0.5;
    spinner.frame = frame;
    [loadingView addSubview:spinner];
}

- (void)addLoadingView
{
    [self.view addSubview:loadingView];
}

- (void)updateProgress
{
    if (trackLength > 0.0) {
        double progress = self.normalizedPlaybackTime / trackLength;
        // NSLog(@"Setting track progress to %f", progress);
        _trackProgress.progress = progress;
    }
    else {
        _trackProgress.progress = 0.0;
    }
    [self updateLabel:_trackProgressLabel withTime:self.normalizedPlaybackTime];
}

- (void)updateLabel:(UILabel*)label withTime:(double)time
{
    double dMinutes = 0.0;
    double dSeconds = modf(time/60.0, &dMinutes) * 60.0 + 0.5;

    int minutes = dMinutes;
    int seconds = dSeconds;
    if (seconds == 60) {
        ++ minutes;
        seconds = 0;
    }
    label.text = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
}

@end
