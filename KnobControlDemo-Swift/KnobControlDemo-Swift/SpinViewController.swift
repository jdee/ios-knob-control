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
class SpinViewController: BaseViewController, MPMediaPickerControllerDelegate {

    // MARK: Storyboard outlets
    @IBOutlet var knobHolder : UIView!
    @IBOutlet var iTunesButton : UIButton!
    @IBOutlet var trackProgress : UIProgressView!
    @IBOutlet var trackLengthLabel : UILabel!
    @IBOutlet var trackProgressLabel : UILabel!
    @IBOutlet var toolbar: UIToolbar!

    // MARK: other stored properties
    var displayLink : CADisplayLink!
    var musicPlayer : MPMusicPlayerController!
    var mediaCollection : MPMediaItemCollection?
    var volumeView : MPVolumeView!
    var loadingView : UIView!

    var trackLength : Double = 0
    var currentPlaybackTime : Double = 0
    var touchIsDown : Bool = false
    var playbackOffset: Double = 0

    // MARK: constant(s)

    let angularVelocity = 10 * Float(M_PI) / 9 // 33 1/3 RPM = 100 rev./180 s = 10π/9 rad/s

    /*
     * MARK: View lifecycle
     */

    override func viewDidLoad() {
        super.viewDidLoad()

        createKnobControl()
        createMusicPlayer()
        createDisplayLink()
        createLoadingView()
        setupToolbar(musicPlayer.playbackState)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updatePlaybackState", name: MPMusicPlayerControllerPlaybackStateDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "updateCurrentTrack", name: MPMusicPlayerControllerNowPlayingItemDidChangeNotification, object: nil)

        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.foregrounder = self
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateMusicPlayer(musicPlayer.playbackState)
    }

    /*
     * MARK: IBActions, protocol implementations and other callbacks.
     */

    // called when the user taps the button to select a track from iTunes
    @IBAction func selectTrack(sender: UIButton) {
        addLoadingView()

        let picker = MPMediaPickerController(mediaTypes: .AnyAudio)
        picker.allowsPickingMultipleItems = true
        picker.delegate = self
        picker.prompt = "Select track(s)"
        presentViewController(picker, animated: true, completion: nil)
    }

    @IBAction func play(sender: UIBarButtonItem!) {
        if musicPlayer.playbackState != .Playing {
            musicPlayer.currentPlaybackTime = currentPlaybackTime - playbackOffset
            musicPlayer.play()
            updateMusicPlayer(.Playing)
        }
    }

    @IBAction func pause(sender: UIBarButtonItem!) {
        musicPlayer.pause()
        updateMusicPlayer(.Paused)
    }

    // MARK: Foregrounder protocol implementation
    override func resumeFromBackground(appDelegate: AppDelegate) {
        super.resumeFromBackground(appDelegate)
        updateMusicPlayer(musicPlayer.playbackState)
    }

    // MARK: --- implementation of MPMediaPickerControllerDelegate protocol ---

    func mediaPicker(mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        dismissViewControllerAnimated(true, completion: nil)
        loadingView.removeFromSuperview()

        knobControl.enabled = true
        knobControl.foregroundImage = UIImage(named:"tonearm")

        mediaCollection = mediaItemCollection

        musicPlayer.setQueueWithItemCollection(mediaItemCollection)
        musicPlayer.play()

        updateMusicPlayer(.Playing)
    }

    func mediaPickerDidCancel(mediaPicker: MPMediaPickerController) {
        dismissViewControllerAnimated(true, completion: nil)
        loadingView.removeFromSuperview()
    }

    // MARK: callback for the CADisplayLink
    func animateKnob(link: CADisplayLink) {
        // Temporarily, at least, revert to this kluge. The UIControl base class seems to generate the
        // UIControlEventTouchXXX events, and they don't make much sense in this context. Perhaps there's
        // a way to override it with custom behavior, but for now I can't.
        if touchIsDown && !knobControl.highlighted {
            // resume whenever the touch comes up
            // NSLog("when touch came up, current playback time: %f/%f", currentPlaybackTime, trackLength)
            musicPlayer.currentPlaybackTime = currentPlaybackTime - playbackOffset
            if musicPlayer.playbackState != .Playing {
                musicPlayer.beginGeneratingPlaybackNotifications()
                musicPlayer.play()
            }
            // NSLog("touch came up. setting currentPlaybackTime to %f", normalizedPlaybackTime)
        }
        else if !touchIsDown && knobControl.highlighted {
            // pause whenever a touch goes down
            if musicPlayer.playbackState == .Playing {
                musicPlayer.endGeneratingPlaybackNotifications()
                musicPlayer.pause()
            }
            currentPlaybackTime = musicPlayer.currentPlaybackTime + playbackOffset
            // NSLog("Touch went down. Current playback time: %f/%f", currentPlaybackTime, trackLength)
        }
        touchIsDown = knobControl.highlighted

        // .Stopped shouldn't happen if musicPlayer.repeatMode == .All
        if touchIsDown || musicPlayer.nowPlayingItem == nil {
            // if the user is interacting with the knob (or nothing is selected), don't animate it
            return
        }

        /*
         * If the user is not interacting with the knob, update the currentPlaybackTime, which can
         * be modified by turning the knob (see knobRotated: below), and adjust the position of
         * both the knob and the progress view to reflect the new value.
         */

        currentPlaybackTime = musicPlayer.currentPlaybackTime + playbackOffset

        // link.duration * link.frameInterval is how long it's been since the last invocation of
        // this callback, so this is another alternative:
        // knobControl.position += Float(link.duration) * Float(link.frameInterval) * angularMomentum

        // but this is simpler, given the way the knob control and music player work
        knobControl.position = Float(currentPlaybackTime) * angularVelocity

        updateProgress()
    }

    // MARK: callback for the IOSKnobControl
    func knobRotated(sender: IOSKnobControl) {
        /*
         * Just update this ivar while the knob is being rotated, and adjust the progress view to reflect the same
         * value. Only assign this to the musicPlayer's currentPlaybackTime property once play resumes when the
         * touch comes up. See animateKnob() above.
         */
        currentPlaybackTime = Double(sender.position/angularVelocity)

        if (currentPlaybackTime > playbackOffset + trackLength) {
            musicPlayer.skipToNextItem()
            // NSLog("Skipping to next item")

            playbackOffset += trackLength
            musicPlayer.currentPlaybackTime = currentPlaybackTime - playbackOffset
            updateSelectedItem()
        }
        else if (currentPlaybackTime < playbackOffset) {
            musicPlayer.skipToPreviousItem()
            // NSLog("Skipping to previous item")

            trackLength = musicPlayer.nowPlayingItem!.playbackDuration
            playbackOffset -= trackLength
            musicPlayer.currentPlaybackTime = currentPlaybackTime - playbackOffset
            updateSelectedItem()
        }
        else {
            updateProgress()
        }
    }

    /*
     * MARK: Private convenience functions for DRYness, readability
     */

    private var tonearmShadowPath: UIBezierPath {
        get {
            let path = UIBezierPath()

            let circleCenter = CGPointMake(258.25, 26.75)

            path.moveToPoint(CGPointMake(206, 225))
            path.addLineToPoint(CGPointMake(227, 235.5))
            path.addLineToPoint(CGPointMake(229, 229))
            path.addLineToPoint(CGPointMake(236.5, 232.5))
            path.addLineToPoint(CGPointMake(238, 229))
            path.addLineToPoint(CGPointMake(230, 224))
            path.addLineToPoint(CGPointMake(236, 201))
            path.addLineToPoint(CGPointMake(249, 167.5))
            path.addLineToPoint(CGPointMake(259, 45.5))
            path.addArcWithCenter(circleCenter, radius: 18.76, startAngle: -1.5308, endAngle: 1.5308, clockwise: false)
            path.addLineToPoint(CGPointMake(263, 2))
            path.addLineToPoint(CGPointMake(257.5, 2))
            path.addLineToPoint(CGPointMake(257.5, 8))
            path.addArcWithCenter(circleCenter, radius: 18.76, startAngle: 1.6108, endAngle: 4.673, clockwise: false)
            path.addLineToPoint(CGPointMake(243.5, 166))
            path.addLineToPoint(CGPointMake(229, 197.5))
            path.addLineToPoint(CGPointMake(226, 196))
            path.closePath()
            return path
        }
    }

    private func createKnobControl() {
        // use UIImage(named: "disc") for the .Normal state
        knobControl = IOSKnobControl(frame:knobHolder.bounds, imageNamed:"disc")
        knobControl.mode = .Continuous
        knobControl.circular = true
        knobControl.clockwise = true
        knobControl.enabled = false    // wait till a track is selected to enable the control
        knobControl.normalized = false // this lets us fast forward and rewind using the knob
        knobControl.addTarget(self, action: "knobRotated:", forControlEvents: .ValueChanged)
        knobControl.setImage(UIImage(named:"disc-disabled"), forState: .Disabled)
        knobControl.shadowOpacity = 1.0
        knobControl.clipsToBounds = false
        knobControl.masksImage = true

        // NOTE: This is an important optimization when using a custom circular image with a shadow.
        knobControl.knobRadius = 0.5 * knobControl.bounds.size.width
        knobHolder.addSubview(knobControl)
    }

    private func createDisplayLink() {
        // CADisplayLink from CoreAnimation/QuartzCore calls the supplied selector on the main thread
        // whenever it's time to prepare a frame for display. It includes a lot of conveniences, like
        // easy scaling of the frame rate and automatic pause on background.
        displayLink = CADisplayLink(target: self, selector: "animateKnob:")
        displayLink.frameInterval = 3 // 20 fps
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)

        if musicPlayer.playbackState == .Playing {
            displayLink.paused = false
        }
    }

    private func createMusicPlayer() {
        // could do this as a lazy prop or even a constant initializer perhaps
        musicPlayer = MPMusicPlayerController.iPodMusicPlayer()
        musicPlayer.repeatMode = .All
        musicPlayer.beginGeneratingPlaybackNotifications()

        updateSelectedItem()
    }

    private func createLoadingView() {
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

    private func addLoadingView() {
        view.addSubview(loadingView)
    }

    private func setupToolbar(playbackState: MPMusicPlaybackState) {
        let width = toolbar.bounds.size.width - 60

        // this is the recommended (only?) way to adjust the system volume, which is what the
        // MPMusicPlayerController requires. it's unsatisfying in a knob-control demo not to be able
        // to use a volume knob.

        // origin x and y don't matter here. I can specify the width of the bar button item and the height of the volumeView.
        // I can't control the absolute positioning within the toolbar.
        volumeView = MPVolumeView(frame:CGRectMake(0, 0, width, toolbar.bounds.size.height - 16))
        volumeView.layer.borderColor = UIColor.blackColor().CGColor
        // volumeView.layer.borderWidth = 1

        let volumeItem = UIBarButtonItem(customView: volumeView)
        volumeItem.width = width

        if musicPlayer.nowPlayingItem == nil || playbackState == .Playing {
            toolbar.items = [ UIBarButtonItem(barButtonSystemItem: .Pause, target: self, action: "pause:"), volumeItem ]
        }
        else {
            toolbar.items = [ UIBarButtonItem(barButtonSystemItem: .Play, target: self, action: "play:"), volumeItem ]
        }

        if musicPlayer.nowPlayingItem == nil {
            let pauseButton = toolbar.items![0] 
            pauseButton.enabled = false
        }
    }

    private func updateProgress() {
        if trackLength > 0 {
            let progress = (currentPlaybackTime - playbackOffset) / trackLength
            // NSLog("Setting track progress to %f", progress)
            trackProgress.progress = Float(progress)
        }
        else {
            trackProgress.progress = 0
        }
        updateLabel(trackProgressLabel, withTime: currentPlaybackTime - playbackOffset)
    }

    private func updateLabel(label:UILabel, withTime time:Double) {
        var minutes = Int(time / 60)       // this is a floor
        var seconds = Int(time % 60 + 0.5) // this is rounded up or down
        if seconds == 60 {
            // if seconds rounds up to 60, increment minutes
            ++minutes
            seconds = 0
        }
        label.text = String(format: "%d:%02d", minutes, seconds)
    }

    func updateCurrentTrack() {
        currentPlaybackTime = Double(knobControl.position / angularVelocity)
        playbackOffset = currentPlaybackTime - musicPlayer.currentPlaybackTime // essentially reset this offset whenever we change tracks, since we don't know whether we went forward or backward

        NSLog("knob position: %f. current playback time: %f. music player playback time: %f. playback offset is now %f", knobControl.position, currentPlaybackTime, musicPlayer.currentPlaybackTime, playbackOffset)
        updateMusicPlayer(musicPlayer.playbackState)
    }

    func updatePlaybackState() {
        if musicPlayer.playbackState != .Playing {
            /*
             * DEBT: This fixes a particular scenario: Pause anything you're playing in the demo. Tap the button
             * at the top to select a new iTunes track. Once you select a new track, the picker view goes away,
             * the track starts playing, and the knob doesn't turn. The reason? After the mediaPicker:didPickYadda: call
             * we get a call here with playbackState != .Playing. Everything else seems to work.
             */
            return
        }
        updateMusicPlayer(musicPlayer.playbackState)
    }

    private func updateMusicPlayer(playbackState: MPMusicPlaybackState) {
        // The user could muck around with the iPod app while we're in the bg.
        displayLink.paused = playbackState != .Playing

        #if VERBOSE
            NSLog("Current playback state: \(examinePlaybackState(playbackState))")
        #endif

        updateSelectedItem()
        setupToolbar(playbackState)
    }

    private func updateSelectedItem() {
        if musicPlayer.nowPlayingItem != nil {
            trackLength = musicPlayer.nowPlayingItem!.playbackDuration
            // NSLog("Selected item duration is %f", trackLength)
            updateLabel(trackLengthLabel, withTime: trackLength)

            currentPlaybackTime = musicPlayer.currentPlaybackTime + playbackOffset
            // NSLog("Current playback time is %f", currentPlaybackTime)
            updateProgress()

            // NSLog("Updated selected item: %@: %f (%f - %f)/%f", musicPlayer.nowPlayingItem.title, musicPlayer.currentPlaybackTime, currentPlaybackTime, playbackOffset, trackLength)

            let trackName = musicPlayer.nowPlayingItem!.title
            let artist = musicPlayer.nowPlayingItem!.artist
            iTunesButton.setTitle(String(format: "%@ - %@", artist!, trackName!), forState: .Normal)

            knobControl.setImage(UIImage(named: "disc"), forState: .Normal)

            let artwork = musicPlayer.nowPlayingItem!.artwork
            if artwork != nil {
                let image = artwork!.imageWithSize(knobControl.bounds.size)
                if image != nil {
                    knobControl.setImage(image, forState: .Normal)
                }
            }

            knobControl.enabled = true
            knobControl.position = angularVelocity * Float(currentPlaybackTime)
            knobControl.foregroundImage = UIImage(named: "tonearm")
            knobControl.foregroundLayerShadowPath = tonearmShadowPath
        }
        else {
            iTunesButton.setTitle("Select iTunes track(s)", forState: .Normal)

            if displayLink != nil {
                displayLink.paused = true
            }

            if knobControl != nil {
                knobControl.enabled = false
                knobControl.foregroundImage = nil
            }

            playbackOffset = 0
            updateLabel(trackLengthLabel, withTime: 0)
            updateLabel(trackProgressLabel, withTime: 0)
            updateProgress()
        }
    }

    private func examinePlaybackState(playbackState: MPMusicPlaybackState) -> String {
        switch (playbackState) {
        case .Playing:
            return "Playing"
        case .Paused:
            return "Paused"
        case .Interrupted:
            return "Interrupted"
        case .SeekingBackward:
            return "SeekingBackward"
        case .SeekingForward:
            return "SeekingForward"
        case .Stopped:
            return "Stopped"
        }
    }
}
