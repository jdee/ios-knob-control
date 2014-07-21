/*
Copyright (c) 2013-14, Jimmy Dee
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import MediaPlayer
import QuartzCore // for CADisplayLink
import UIKit

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
class SpinViewController: UIViewController, MPMediaPickerControllerDelegate, Foregrounder {

    // Storyboard outlets
    @IBOutlet var knobHolder : UIView!
    @IBOutlet var iTunesButton : UIButton!
    @IBOutlet var trackProgress : UIProgressView!
    @IBOutlet var trackLengthLabel : UILabel!
    @IBOutlet var trackProgressLabel : UILabel!
    @IBOutlet var volumeViewHolder : UIView!

    // other stored properties
    var knobControl : IOSKnobControl!
    var displayLink : CADisplayLink!
    var musicPlayer : MPMusicPlayerController!
    var mediaCollection : MPMediaItemCollection?
    var volumeView : MPVolumeView!
    var loadingView : UIView!

    var trackLength : Double = 0
    var currentPlaybackTime : Double = 0
    var touchIsDown : Bool = false

    // computed properties

    var normalizedPlaybackTime : Double {
    get {
        var playbackTime = currentPlaybackTime % trackLength
        if playbackTime < 0 {
            playbackTime += trackLength
        }
        return playbackTime
    }
    }

    var appDelegate : AppDelegate {
    get {
        return UIApplication.sharedApplication().delegate as AppDelegate
    }
    }

    // constant(s)

    let angularVelocity = 10 * Float(M_PI) / 9 // 33 1/3 RPM = 100 rev./180 s

    /*
     * Never thought I'd miss the preprocessor, but where's mah pragma mark?
     */

    /*
     * View lifecycle
     */

    override func viewDidLoad() {
        super.viewDidLoad()

        createKnobControl()
        createDisplayLink()
        createMusicPlayer()
        createLoadingView()

        // arrange to be notified via resumeFromBackground() when the app becomes active
        appDelegate.foregrounder = self
    }

    override func viewDidDisappear(animated: Bool) {
        if musicPlayer.nowPlayingItem {
            musicPlayer.pause()
            displayLink.paused = true
        }
        super.viewDidDisappear(animated)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if musicPlayer.nowPlayingItem {
            musicPlayer.play()
            displayLink.paused = false
        }
    }

    /*
     * IBActions, protocol implementations and other callbacks.
     */

    // called when the user taps the button to select a track from iTunes
    @IBAction func selectTrack(sender: UIButton) {
        addLoadingView()

        let picker = MPMediaPickerController(mediaTypes: .AnyAudio)
        picker.allowsPickingMultipleItems = false
        picker.delegate = self
        picker.prompt = "Select a track"
        presentViewController(picker, animated: true, completion: nil)
    }

    // --- implementation of Foregrounder protocol ---

    func resumeFromBackground(appDelegate: AppDelegate) {
        /*
         * The MPMusicPlayerController dumps the user's selection when the app is backgrounded.
         * This is OK for this demo app, but reset the view to its state when no track is
         * selected, prompting the user to select again.
         */
        knobControl.position = 0
        knobControl.enabled = false
        knobControl.foregroundImage = nil
        currentPlaybackTime = 0
        trackLength = 0
        updateProgress()
        updateLabel(trackLengthLabel, withTime: trackLength)
        iTunesButton.setTitle("select iTunes track", forState: .Normal)
    }

    // --- implementation of MPMediaPickerControllerDelegate protocol ---

    func mediaPicker(mediaPicker: MPMediaPickerController!, didPickMediaItems mediaItemCollection: MPMediaItemCollection!) {
        dismissViewControllerAnimated(true, completion: nil)
        loadingView.removeFromSuperview()

        knobControl.enabled = true
        knobControl.foregroundImage = UIImage(named:"tonearm")

        mediaCollection = mediaItemCollection

        musicPlayer.setQueueWithItemCollection(mediaItemCollection)
        musicPlayer.play()
        displayLink.paused = false

        trackLength = musicPlayer.nowPlayingItem.valueForProperty(MPMediaItemPropertyPlaybackDuration) as Double
        NSLog("Selected item duration is %f", trackLength)
        updateLabel(trackLengthLabel, withTime: trackLength)

        let trackName = musicPlayer.nowPlayingItem.valueForProperty(MPMediaItemPropertyTitle) as String
        let artist = musicPlayer.nowPlayingItem.valueForProperty(MPMediaItemPropertyArtist) as String
        iTunesButton.setTitle(String(format: "%@ - %@", artist, trackName), forState: .Normal)
    }

    func mediaPickerDidCancel(mediaPicker: MPMediaPickerController!) {
        dismissViewControllerAnimated(true, completion: nil)
        loadingView.removeFromSuperview()
    }

    // callback for the CADisplayLink
    func animateKnob(link: CADisplayLink) {
        // Temporarily, at least, revert to this kluge. The UIControl base class seems to generate the
        // UIControlEventTouchXXX events, and they don't make much sense in this context. Perhaps there's
        // a way to override it with custom behavior, but for now I can't.
        if touchIsDown && !knobControl.highlighted {
            // resume whenever the touch comes up
            musicPlayer.currentPlaybackTime = normalizedPlaybackTime
            musicPlayer.play()
            NSLog("touch came up. setting currentPlaybackTime to %f", normalizedPlaybackTime)
        }
        else if !touchIsDown && knobControl.highlighted {
            // pause whenever a touch goes down
            musicPlayer.pause()
            currentPlaybackTime = musicPlayer.currentPlaybackTime
        }
        touchIsDown = knobControl.highlighted

        // .Stopped shouldn't happen if musicPlayer.repeatMode == .All
        if touchIsDown || !musicPlayer.nowPlayingItem || musicPlayer.playbackState == .Stopped {
            // if the user is interacting with the knob (or nothing is selected), don't animate it
            return
        }

        /*
         * If the user is not interacting with the knob, update the currentPlaybackTime, which can
         * be modified by turning the knob (see knobRotated: below), and adjust the position of
         * both the knob and the progress view to reflect the new value.
         */

        currentPlaybackTime = musicPlayer.currentPlaybackTime

        // link.duration * link.frameInterval is how long it's been since the last invocation of
        // this callback, so this is another alternative:
        // knobControl.position += Float(link.duration) * Float(link.frameInterval) * angularMomentum

        // but this is simpler, given the way the knob control and music player work
        knobControl.position = Float(currentPlaybackTime) * angularVelocity

        updateProgress()
    }

    // callback for the IOSKnobControl
    func knobRotated(sender: IOSKnobControl) {
        /*
         * Just update this ivar while the knob is being rotated, and adjust the progress view to reflect the same
         * value. Only assign this to the musicPlayer's currentPlaybackTime property once play resumes when the
         * touch comes up. See animateKnob() above.
         */
        currentPlaybackTime = Double(sender.position/angularVelocity)
        updateProgress()
    }

    /*
     * Internal convenience functions for DRYness, readability, and, in other languages, privacy.
     */

    func createKnobControl() {
        // use UIImage(named: "disc") for the .Normal state
        knobControl = IOSKnobControl(frame:knobHolder.bounds, imageNamed:"disc")
        knobControl.mode = .Continuous
        knobControl.circular = true
        knobControl.clockwise = true
        knobControl.enabled = false    // wait till a track is selected to enable the control
        knobControl.normalized = false // this lets us fast forward and rewind using the knob
        knobControl.addTarget(self, action: "knobRotated:", forControlEvents: .ValueChanged)
        knobControl.setImage(UIImage(named:"disc-disabled"), forState: .Disabled)
        knobHolder.addSubview(knobControl)
    }

    func createDisplayLink() {
        // CADisplayLink from CoreAnimation/QuartzCore calls the supplied selector on the main thread
        // whenever it's time to prepare a frame for display. It includes a lot of conveniences, like
        // easy scaling of the frame rate and automatic pause on background.
        displayLink = CADisplayLink(target: self, selector: "animateKnob:")
        displayLink.frameInterval = 3 // 20 fps
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }

    func createMusicPlayer() {
        // could do this as a lazy prop or even a constant initializer perhaps
        musicPlayer = MPMusicPlayerController.applicationMusicPlayer()
        musicPlayer.repeatMode = .All

        // this is the recommended (only?) way to adjust the system volume, which is what the
        // MPMusicPlayerController requires. it's unsatisfying in a knob-control demo not to be able
        // to use a volume knob. it might be possible to use the AVAudioPlayer with items from the
        // MPMediaPicker. I've had spotty results adjusting the AVAudioPlayer volume before though.
        // maybe this demo doesn't need to adjust the volume, but at least this is very simple.
        volumeView = MPVolumeView(frame:volumeViewHolder.bounds)
        volumeViewHolder.addSubview(volumeView)
    }

    func createLoadingView() {
        // The iTunes library load can take a little time, which can be confusing, so we can provide some feedback and disable
        // the whole view by adding a transparent view on top with an activity spinner. This is added as a subview of the main
        // view, on top of everything else, in selectTrack(), when the user taps the button. This is kind of hard to do in the
        // storyboard.
        // This could be the reason for the delay: <MPRemoteMediaPickerController: 0x14e723e0> timed out waiting for fence barrier from com.apple.MusicUIService
        loadingView = UIView(frame: view.bounds)
        loadingView.opaque = false
        loadingView.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)

        let spinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
        spinner.startAnimating()
        spinner.frame.origin.x = (view.bounds.size.width - spinner.frame.size.width) * 0.5
        spinner.frame.origin.y = (view.bounds.size.height - spinner.frame.size.height) * 0.5
        loadingView.addSubview(spinner)
    }

    func addLoadingView() {
        view.addSubview(loadingView)
    }

    func updateProgress() {
        if trackLength > 0 {
            let progress = normalizedPlaybackTime / trackLength
            // NSLog("Setting track progress to %f", progress)
            trackProgress.progress = Float(progress)
        }
        else {
            trackProgress.progress = 0
        }
        updateLabel(trackProgressLabel, withTime: normalizedPlaybackTime)
    }

    func updateLabel(label:UILabel, withTime time:Double) {
        var minutes = Int(time / 60)       // this is a floor
        var seconds = Int(time % 60 + 0.5) // this is rounded up or down
        if seconds == 60 {
            // if seconds rounds up to 60, increment minutes
            ++minutes
            seconds = 0
        }
        label.text = String(format: "%d:%02d", minutes, seconds)
    }
}
