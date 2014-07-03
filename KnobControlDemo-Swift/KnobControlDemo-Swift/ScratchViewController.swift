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

class ScratchViewController: UIViewController, MPMediaPickerControllerDelegate, Foregrounder {

    @IBOutlet var knobHolder : UIView
    @IBOutlet var iTunesButton : UIButton
    @IBOutlet var trackProgress : UIProgressView
    @IBOutlet var trackLengthLabel : UILabel
    @IBOutlet var trackProgressLabel : UILabel

    var knobControl : IOSKnobControl!
    var displayLink : CADisplayLink!
    var musicPlayer : MPMusicPlayerController!
    var mediaCollection : MPMediaItemCollection?
    var loadingView : UIView!

    var lastPosition : Float = 0
    var trackLength : Double = 0
    var currentPlaybackTime : Double = 0
    var touchIsDown : Bool = false

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

    let angularMomentum = 10 * Float(M_PI) / 9 // 33 1/3 RPM = 100 rev./180 s

    override func viewDidLoad() {
        super.viewDidLoad()

        NSLog("view did load")

        knobControl = IOSKnobControl(frame:knobHolder.bounds, imageNamed:"disc")
        knobControl.mode = .Continuous
        knobControl.circular = true
        knobControl.clockwise = true
        knobControl.enabled = false    // wait till a track is selected to enable the control
        knobControl.normalized = false // this lets us fast forward and rewind using the knob

        knobControl.addTarget(self, action: "knobRotated:", forControlEvents: .ValueChanged)

        knobHolder.addSubview(knobControl)

        lastPosition = knobControl.position // 0 anyway

        // CADisplayLink from CoreAnimation/QuartzCore calls the supplied selector on the main thread
        // whenever it's time to prepare a frame for display. It includes a lot of conveniences, like
        // easy scaling of the frame rate and automatic pause on background.
        displayLink = CADisplayLink(target: self, selector: "animateKnob:")
        displayLink.frameInterval = 3 // 20 fps
        displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)

        // could do this as a lazy prop or even a constant initializer perhaps
        musicPlayer = MPMusicPlayerController.applicationMusicPlayer()
        musicPlayer.repeatMode = .All

        // arrange to be notified via resumeFromBackground() when the app becomes active
        appDelegate.foregrounder = self

        // The iTunes library load can take a little time, which can be confusing, so we can provide some feedback and disable
        // the whole view by adding a transparent view on top with an activity spinner. This is added as a subview of the main
        // view, on top of everything else, in selectTrack(), when the user taps the button. This is kind of hard to do in the
        // storyboard.
        loadingView = UIView(frame: view.bounds)
        loadingView.opaque = false
        loadingView.backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)

        let spinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
        spinner.startAnimating()
        spinner.frame.origin.x = (view.bounds.size.width - spinner.frame.size.width) * 0.5
        spinner.frame.origin.y = (view.bounds.size.height - spinner.frame.size.height) * 0.5
        loadingView.addSubview(spinner)
        loadingView.addConstraint(NSLayoutConstraint(item: spinner, attribute: .Leading, relatedBy: .Equal, toItem: loadingView, attribute: .Leading, multiplier: 1.0, constant: spinner.frame.origin.x))
        loadingView.addConstraint(NSLayoutConstraint(item: spinner, attribute: .Top, relatedBy: .Equal, toItem: loadingView, attribute: .Top, multiplier: 1.0, constant: spinner.frame.origin.y))
    }

    func addLoadingView() {
        view.addSubview(loadingView)
        /* The main reason for using constraints here (with rotation disabled) is to make the views in this demo layout properly on iOS 6 as well as 7+. This works on iOS 7, but not on 6 for some reason.
         * However, it's also quite unnecessary. But it should work, I think.
        view.addConstraint(NSLayoutConstraint(item: loadingView, attribute: .Top, relatedBy: .Equal, toItem: view, attribute: .Top, multiplier: 1.0, constant: 0.0))
        view.addConstraint(NSLayoutConstraint(item: loadingView, attribute: .Bottom, relatedBy: .Equal, toItem: view, attribute: .Bottom, multiplier: 1.0, constant: 0.0))
        view.addConstraint(NSLayoutConstraint(item: loadingView, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1.0, constant: 0.0))
        view.addConstraint(NSLayoutConstraint(item: loadingView, attribute: .Trailing, relatedBy: .Equal, toItem: view, attribute: .Trailing, multiplier: 1.0, constant: 0.0))
         */
    }

    override func viewWillUnload()  {
        NSLog("view will unload")
        // not sure if this is necessary
        displayLink.invalidate()
        super.viewWillUnload()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        if musicPlayer.nowPlayingItem {
            musicPlayer.pause()
            displayLink.paused = true
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if musicPlayer.nowPlayingItem {
            musicPlayer.play()
            displayLink.paused = false
        }
    }

    func resumeFromBackground(appDelegate: AppDelegate) {
        /*
         * The MPMusicPlayerController dumps the user's selection when the app is backgrounded.
         * This is OK for this demo app, but reset the view to its state when no track is
         * selected, prompting the user to select again.
         */
        knobControl.position = 0
        currentPlaybackTime = 0
        trackLength = 0
        updateProgress()
        updateLabel(trackLengthLabel, withTime: trackLength)
        iTunesButton.setTitle("select iTunes track", forState: .Normal)
    }

    // called when the user taps the button to select a track from iTunes
    @IBAction func selectTrack(sender: UIButton) {
        addLoadingView()

        let picker = MPMediaPickerController(mediaTypes: .AnyAudio)
        picker.allowsPickingMultipleItems = false
        picker.delegate = self
        picker.prompt = "Select a track"
        presentViewController(picker, animated: true, completion: nil)
    }

    func animateKnob(link: CADisplayLink) {
        // cheap way of detecting touch down/up events in this unusual scenario
        if !touchIsDown && knobControl.highlighted {
            musicPlayer.pause()
            currentPlaybackTime = musicPlayer.currentPlaybackTime
        }
        else if touchIsDown && !knobControl.highlighted {
            musicPlayer.play()
            NSLog("touch came up. setting currentPlaybackTime to %f", normalizedPlaybackTime)
            musicPlayer.currentPlaybackTime = normalizedPlaybackTime
        }
        touchIsDown = knobControl.highlighted

        // .Stopped shouldn't happen if musicPlayer.repeatMode == .All
        if touchIsDown || !musicPlayer.nowPlayingItem || musicPlayer.playbackState == .Stopped {
            return
        }

        knobControl.position += Float(link.duration) * angularMomentum * Float(link.frameInterval)
        lastPosition = knobControl.position
        currentPlaybackTime = musicPlayer.currentPlaybackTime

        updateProgress()
    }

    func updateProgress() {
        let progress = normalizedPlaybackTime / trackLength
        // NSLog("Setting track progress to %f", progress)
        trackProgress.progress = Float(progress)
        updateLabel(trackProgressLabel, withTime: normalizedPlaybackTime)
    }

    func mediaPicker(mediaPicker: MPMediaPickerController!, didPickMediaItems mediaItemCollection: MPMediaItemCollection!) {
        dismissViewControllerAnimated(true, completion: nil)
        loadingView.removeFromSuperview()

        knobControl.enabled = true

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

    func knobRotated(sender: IOSKnobControl) {
        var delta = sender.position - lastPosition
        lastPosition = sender.position

        // NSLog("delta is %f; delta/omega = %f; currentPlaybackTime is %f", delta, Double(delta/angularMomentum), currentPlaybackTime)

        currentPlaybackTime += Double(delta/angularMomentum)

        updateProgress()
    }

    func updateLabel(label:UILabel, withTime time:Double) {
        var minutes = Int(time / 60)       // this is a floor
        var seconds = Int(time % 60 + 0.5) // this is rounded up
        if seconds == 60 {
            // if seconds rounds up to 60, increment minutes
            ++minutes
            seconds = 0
        }
        label.text = String(format: "%d:%02d", minutes, seconds)
    }
}
