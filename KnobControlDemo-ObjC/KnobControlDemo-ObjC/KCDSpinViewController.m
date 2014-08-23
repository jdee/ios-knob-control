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

/*
 * This demo presents a music player using an animated knob control to simulate a spinning 33 1/3 RPM vinyl record and
 * play a single track from the user's iTunes library in an infinite loop.
 * You can control the playback position by manually rotating the record using one-finger rotation. The position and
 * track length are indicated using labels and a progress view. There is also a system volume control, but see the
 * comments below in createMusicPlayer(). Note that the MPMusicPlayerController by default loses its state when the
 * app enters the background. It stops playing, and it cannot resume with a simple call to play() after it returns to
 * the foreground. A real music player app should solve this problem and allow playback to continue in the background,
 * but for this demo, which is already a little more complex than the other tabs, we just restore the view to its initial
 * state whenever it enters the foreground and let the user pick a new song.
 *
 * Also note that this is a case where the knob is no longer a knob. To simulate a turntable, the knob is made to rotate
 * continuously at a constant angular velocity in the absence of gestures from the user. This is a novel use of the control.
 * The animation is done externally with the assistance of the CADisplayLink utility from QuartzCore.
 */
@implementation KCDSpinViewController {
    CADisplayLink* displayLink;
    MPMusicPlayerController* musicPlayer;
    MPMediaItemCollection* mediaCollection;
    MPVolumeView* volumeView;
    UIView* loadingView;

    double trackLength, currentPlaybackTime;
    BOOL touchIsDown;
}

// This never seems to make a bit of difference. Hence I forgot one of these originally.
@dynamic normalizedPlaybackTime, appDelegate;

- (double)normalizedPlaybackTime
{
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
    [self createMusicPlayer];
    [self createDisplayLink];
    [self createLoadingView];

    [self setupToolbar:musicPlayer.playbackState];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePlaybackState) name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:nil];

    // arrange to be notified via resumeFromBackground() when the app becomes active
    self.appDelegate.foregrounder = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateMusicPlayer:musicPlayer.playbackState];
}

#pragma mark - IBActions, protocol implementations and other callbacks

// called when the user taps the button to select a track from iTunes
- (void)selectTrack:(UIButton *)sender
{
    [self addLoadingView];

    MPMediaPickerController* mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];
    mediaPicker.allowsPickingMultipleItems = NO;
    mediaPicker.delegate = self;
    mediaPicker.prompt = @"Select a track";
    [self presentViewController:mediaPicker animated:YES completion:nil];
}

- (void)togglePlayState:(UIBarButtonItem*)sender
{
    if (musicPlayer.nowPlayingItem) {
        if (musicPlayer.playbackState == MPMusicPlaybackStatePaused || musicPlayer.playbackState == MPMusicPlaybackStateStopped) {
            [musicPlayer play];
            [self updateMusicPlayer:MPMusicPlaybackStatePlaying];
        }
        else {
            [musicPlayer pause];
            [self updateMusicPlayer:MPMusicPlaybackStatePaused];
        }
    }
}

// --- implementation of Foregrounder protocol ---

- (void)resumeFromBackground:(KCDAppDelegate *)theAppDelegate
{
    [self updateMusicPlayer:musicPlayer.playbackState];
}

// --- implementation of MPMediaPickerControllerDelegate protocol ---

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [loadingView removeFromSuperview];

    self.knobControl.enabled = YES;
    self.knobControl.foregroundImage = [UIImage imageNamed:@"tonearm"];

    mediaCollection = mediaItemCollection;

    [musicPlayer setQueueWithItemCollection:mediaCollection];
    [musicPlayer play];
    displayLink.paused = NO;

    [self updateMusicPlayer:MPMusicPlaybackStatePlaying];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [loadingView removeFromSuperview];
}

// callback for the IOSKnobControl
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

// callback for the CADisplayLink
- (void)animateKnob:(CADisplayLink*)link
{
    if (touchIsDown && !self.knobControl.highlighted) {
        // resume whenever the touch comes up
        musicPlayer.currentPlaybackTime = self.normalizedPlaybackTime;
        [musicPlayer beginGeneratingPlaybackNotifications];
        [musicPlayer play];
    }
    else if (!touchIsDown && self.knobControl.highlighted) {
        // pause whenever a touch goes down
        [musicPlayer endGeneratingPlaybackNotifications];
        [musicPlayer pause];
        currentPlaybackTime = musicPlayer.currentPlaybackTime;
    }
    touchIsDown = self.knobControl.highlighted;

    // .Stopped shouldn't happen if musicPlayer.repeatMode == .All
    if (touchIsDown || !musicPlayer.nowPlayingItem) {
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
    // self.knobControl.position += Float(link.duration) * Float(link.frameInterval) * angularMomentum

    // but this is simpler, given the way the knob control and music player work
    self.knobControl.position = currentPlaybackTime * IKC_33RPM_ANGULAR_VELOCITY;

    [self updateProgress];
}

#pragma mark - Private methods

- (void)createKnobControl
{
    self.knobControl = [[IOSKnobControl alloc] initWithFrame:_knobHolder.bounds imageNamed:@"disc"];
    self.knobControl.mode = IKCModeContinuous;
    self.knobControl.clockwise = YES;
    self.knobControl.circular = YES;
    self.knobControl.normalized = NO;
    self.knobControl.enabled = NO;
    self.knobControl.shadowOpacity = 1.0;
    self.knobControl.clipsToBounds = NO;

    // NOTE: This is an important optimization when using a custom circular image with a shadow.
    self.knobControl.circularShadowPathRadius = 0.5 * self.knobControl.bounds.size.width;

    [self.knobControl addTarget:self action:@selector(knobRotated:) forControlEvents:UIControlEventValueChanged];
    [self.knobControl setImage:[UIImage imageNamed:@"disc-disabled"] forState:UIControlStateDisabled];
    [_knobHolder addSubview:self.knobControl];
}

- (void)createDisplayLink
{
    // CADisplayLink from CoreAnimation/QuartzCore calls the supplied selector on the main thread
    // whenever it's time to prepare a frame for display. It includes a lot of conveniences, like
    // easy scaling of the frame rate and automatic pause on background.
    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(animateKnob:)];
    displayLink.frameInterval = 3; // 20 fps
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];

    if (musicPlayer.playbackState == MPMusicPlaybackStatePlaying) {
        displayLink.paused = NO;
    }
}

- (void)createMusicPlayer
{
    musicPlayer = [MPMusicPlayerController iPodMusicPlayer];
    musicPlayer.repeatMode = MPMusicRepeatModeAll;
    [musicPlayer beginGeneratingPlaybackNotifications];

    [self updateSelectedItem];
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

- (void)setupToolbar:(MPMusicPlaybackState)playbackState
{
    CGFloat width = _toolbar.bounds.size.width - 60;

    volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0, 0, width, _toolbar.bounds.size.height - 16)];
    UIBarButtonItem* volumeItem = [[UIBarButtonItem alloc] initWithCustomView:volumeView];
    volumeItem.width = width;

    if (!musicPlayer.nowPlayingItem || playbackState == MPMusicPlaybackStatePlaying) {
        _toolbar.items = @[ [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(togglePlayState:)], volumeItem ];
    }
    else {
        _toolbar.items = @[ [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(togglePlayState:)], volumeItem ];
    }

    if (!musicPlayer.nowPlayingItem) {
        UIBarButtonItem* pauseButton = _toolbar.items.firstObject;
        pauseButton.enabled = NO;
    }
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

- (void)updatePlaybackState
{
    if (musicPlayer.playbackState != MPMusicPlaybackStatePlaying) return;

    [self updateMusicPlayer:musicPlayer.playbackState];
}

- (void)updateMusicPlayer:(MPMusicPlaybackState)playbackState
{
    displayLink.paused = playbackState != MPMusicPlaybackStatePlaying;
    [self updateSelectedItem];
    [self setupToolbar:playbackState];
}

- (void)updateSelectedItem
{
    if (musicPlayer.nowPlayingItem) {
        trackLength = ((NSNumber*)[musicPlayer.nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration]).doubleValue;
        NSLog(@"Selected item duration is %f", trackLength);
        [self updateLabel:_trackLengthLabel withTime:trackLength];

        currentPlaybackTime = musicPlayer.currentPlaybackTime;
        [self updateLabel:_trackProgressLabel withTime:currentPlaybackTime];

        [self updateProgress];

        NSString* title = (NSString*)[musicPlayer.nowPlayingItem valueForProperty:MPMediaItemPropertyTitle];
        NSString* artist = (NSString*)[musicPlayer.nowPlayingItem valueForProperty:MPMediaItemPropertyArtist];
        [_iTunesButton setTitle:[NSString stringWithFormat:@"%@ - %@", artist, title] forState:UIControlStateNormal];

        self.knobControl.enabled = YES;
        self.knobControl.position = IKC_33RPM_ANGULAR_VELOCITY * currentPlaybackTime;
        self.knobControl.foregroundImage = [UIImage imageNamed:@"tonearm"];
    }
    else {
        [_iTunesButton setTitle:@"select iTunes track" forState:UIControlStateNormal];
        displayLink.paused = YES;
        self.knobControl.enabled = NO;
        self.knobControl.foregroundImage = nil;

        [self updateLabel:_trackProgressLabel withTime:0.0];
        [self updateLabel:_trackLengthLabel withTime:0.0];
        [self updateProgress];
    }
}

@end
