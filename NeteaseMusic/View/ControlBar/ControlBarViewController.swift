//
//  ControlBarViewController.swift
//  NeteaseMusic
//
//  Created by xjbeta on 2019/4/10.
//  Copyright © 2019 xjbeta. All rights reserved.
//

import Cocoa

class ControlBarViewController: NSViewController {
    
    @IBOutlet weak var trackPicButton: NSButton!
    @IBOutlet weak var trackNameTextField: NSTextField!
    @IBOutlet weak var trackSecondNameTextField: NSTextField!

    @IBOutlet weak var previousButton: NSButton!
    @IBOutlet weak var pauseButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var muteButton: NSButton!
    @IBOutlet weak var playlistButton: NSButton!
    @IBOutlet weak var repeatModeButton: NSButton!
    @IBOutlet weak var shuffleModeButton: NSButton!
    
    @IBAction func controlAction(_ sender: NSButton) {
        let pc = PlayCore.shared
        
        let player = pc.player
        let preferences = Preferences.shared
        switch sender {
        case previousButton:
            pc.previousSong()
        case pauseButton:
            pc.togglePlayPause()
        case nextButton:
            pc.nextSong()
            if pc.fmMode, let id = pc.currentTrack?.id {
                let seconds = Int(pc.currentTime())
                pc.api.radioSkip(id, seconds).done {
                    print("Song skipped, id: \(id) seconds: \(seconds)")
                    }.catch {
                        print($0)
                }
            }
        case muteButton:
            let mute = !pc.isMuted
            pc.isMuted = mute
            preferences.mute = mute
            initVolumeButton()
        case repeatModeButton:
            switch preferences.repeatMode {
            case .noRepeat:
                preferences.repeatMode = .repeatPlayList
            case .repeatPlayList:
                preferences.repeatMode = .repeatItem
            case .repeatItem:
                preferences.repeatMode = .noRepeat
            }
            initPlayModeButton()
        case shuffleModeButton:
            switch preferences.shuffleMode {
            case .noShuffle:
                preferences.shuffleMode = .shuffleItems
            case .shuffleItems:
                preferences.shuffleMode = .noShuffle
            case .shuffleAlbums:
                break
            }
            initPlayModeButton()
        case trackPicButton:
            NotificationCenter.default.post(name: .showPlayingSong, object: nil)
        default:
            break
        }
    }
    
    @IBOutlet weak var durationSlider: PlayerSlider!
    @IBOutlet weak var durationTextField: NSTextField!
    @IBOutlet weak var volumeSlider: NSSlider!
    
    @IBAction func sliderAction(_ sender: NSSlider) {
        let pc = PlayCore.shared
        switch sender {
        case durationSlider:
            var pos = FSStreamPosition()
            pos.position = sender.floatValue
            pc.player.activeStream.seek(to: pos)
            if let eventType = NSApp.currentEvent?.type,
                eventType == .leftMouseUp {
                durationSlider.ignoreValueUpdate = false
            }
        case volumeSlider:
            let v = volumeSlider.floatValue
            PlayCore.shared.player.volume = v
            Preferences.shared.volume = v
            initVolumeButton()
        default:
            break
        }
    }
    
    var playProgressObserver: NSKeyValueObservation?
    var pauseStautsObserver: NSKeyValueObservation?
    var previousButtonObserver: NSKeyValueObservation?
    var currentTrackObserver: NSKeyValueObservation?
    var fmModeObserver: NSKeyValueObservation?
    
    let imgSize = NSSize(width: 15, height: 13)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pauseButton.contentTintColor = .nColor
        previousButton.contentTintColor = .nColor
        nextButton.contentTintColor = .nColor
        if let image = NSImage(named: .init("sf.music.note.list")) {
            image.size = imgSize
            playlistButton.image = image.tint(color: .nColor)
        }
        
        let pc = PlayCore.shared
        
        initVolumeButton()
        
        
        trackPicButton.wantsLayer = true
        trackPicButton.layer?.cornerRadius = 4
        
        trackNameTextField.stringValue = ""
        trackSecondNameTextField.stringValue = ""
        artistButtonsViewController()?.removeAllButtons()
        
        initPlayModeButton()
        
        playProgressObserver = pc.observe(\.playProgress, options: [.initial, .new]) { [weak self] pc, _ in
            guard let slider = self?.durationSlider,
                  let textFiled = self?.durationTextField else { return }
            let player = pc.player
            guard player.activeStream != nil else {
                slider.maxValue = 1
                slider.doubleValue = 0
                slider.cachedDoubleValue = 0
                textFiled.stringValue = "00:00 / 00:00"
                return
            }
            
            let cur = player.activeStream.currentTimePlayed
            let end = player.activeStream.duration
            
            
            slider.maxValue = 1
            
            slider.updateValue(Double(pc.playProgress))
            
            textFiled.stringValue = String(format: "%i:%02i / %i:%02i", cur.minute, cur.second, end.minute, end.second)
        }
        
        pauseStautsObserver = pc.observe(\.playerState, options: [.initial, .new]) { [weak self] (player, changes) in
            switch player.playerState {
            case .playing:
                self?.pauseButton.image = NSImage(named: NSImage.Name("sf.pause.circle"))
            case .paused:
                self?.pauseButton.image = NSImage(named: NSImage.Name("sf.play.circle"))
            default:
                break
            }
        }
        
        previousButtonObserver = pc.observe(\.pnItemType, options: [.initial, .new]) { [weak self] pc, _ in
            
            self?.previousButton.isEnabled = true
            self?.nextButton.isEnabled = true
            
            switch pc.pnItemType {
            case .withoutNext:
                self?.nextButton.isEnabled = false
            case .withoutPrevious:
                self?.previousButton.isEnabled = false
            case .withoutPreviousAndNext:
                self?.nextButton.isEnabled = false
                self?.previousButton.isEnabled = false
            case .other:
                break
            }
            
        }
        
        currentTrackObserver = pc.observe(\.currentTrack, options: [.initial, .new]) { [weak self] pc, _ in
            self?.initViews(pc.currentTrack)
        }
        
        fmModeObserver = pc.observe(\.fmMode, options: [.initial, .new]) { [weak self] (playCore, changes) in
            let fmMode = playCore.fmMode
            self?.previousButton.isHidden = fmMode
            self?.repeatModeButton.isHidden = fmMode
            self?.shuffleModeButton.isHidden = fmMode
        }
        
        if durationSlider.trackingAreas.isEmpty {
            durationSlider.addTrackingArea(NSTrackingArea(rect: durationSlider.frame, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: ["obj": 0]))
        }
    }
    
    
    func initViews(_ track: Track?) {
        if let t = track {
            trackPicButton.setImage(t.album.picUrl?.absoluteString, true)
            trackNameTextField.stringValue = t.name
            let name = t.secondName
            trackSecondNameTextField.isHidden = name == ""
            trackSecondNameTextField.stringValue = name
            artistButtonsViewController()?.initButtons(t, small: true)
            durationTextField.isHidden = false
        } else {
            trackPicButton.image = nil
            trackNameTextField.stringValue = ""
            trackSecondNameTextField.stringValue = ""
            artistButtonsViewController()?.removeAllButtons()
            durationTextField.isHidden = true
        }
        
        durationSlider.maxValue = 1
        durationSlider.doubleValue = 0
        durationSlider.cachedDoubleValue = 0
        durationTextField.stringValue = "00:00 / 00:00"
    }

    
    func initVolumeButton() {
        let pc = PlayCore.shared
        let pref = Preferences.shared
        
        let volume = pref.volume
        volumeSlider.floatValue = volume
        pc.player.volume = volume
        
        let mute = pref.mute
        pc.isMuted = mute
        
        var imageName = ""
        if mute {
            imageName = "sf.speaker.slash"
        } else {
            switch volume {
            case 0:
                imageName = "sf.speaker"
            case 0..<1/3:
                imageName = "sf.speaker.wave.1"
            case 1/3..<2/3:
                imageName = "sf.speaker.wave.2"
            case 2/3...1:
                imageName = "sf.speaker.wave.3"
            default:
                imageName = "sf.speaker"
            }
        }
        guard let image = NSImage(named: NSImage.Name(imageName)) else {
            return
        }
        let h: CGFloat = 14
        let s = image.size
        image.size = .init(width: (s.width / s.height) * h,
                           height: h)
        muteButton.image = image
    }
    
    func initPlayModeButton() {
        let pref = Preferences.shared
        
        let repeatImgName = pref.repeatMode == .repeatItem ? "sf.repeat.1" : "sf.repeat"
        let shuffleImgName = "sf.shuffle"
        
        let repeatImgColor: NSColor = pref.repeatMode == .noRepeat ? .systemGray : .nColor
        let shuffleImgColor: NSColor = pref.shuffleMode == .noShuffle ? .systemGray : .nColor

        let repeatImage = NSImage(named: .init(repeatImgName))
        let shuffleImage = NSImage(named: .init(shuffleImgName))
        
        repeatImage?.size = imgSize
        shuffleImage?.size = imgSize
        
        repeatModeButton.image = repeatImage?.tint(color: repeatImgColor)
        shuffleModeButton.image = shuffleImage?.tint(color: shuffleImgColor)
        
        PlayCore.shared.updateRepeatShuffleMode()
    }
    
    func artistButtonsViewController() -> ArtistButtonsViewController? {
        let vc = children.compactMap {
            $0 as? ArtistButtonsViewController
        }.first
        return vc
    }
    
    deinit {
        playProgressObserver?.invalidate()
        pauseStautsObserver?.invalidate()
        previousButtonObserver?.invalidate()
        currentTrackObserver?.invalidate()
        fmModeObserver?.invalidate()
    }
    
}

extension ControlBarViewController {
    
    override func mouseEntered(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo as? [String: Int],
              userInfo["obj"] == 0 else {
            return
        }
        durationSlider.mouseIn = true
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let userInfo = event.trackingArea?.userInfo as? [String: Int],
              userInfo["obj"] == 0 else {
            return
        }
        durationSlider.mouseIn = false
    }
    
}
