//
//  PlaylistViewController.swift
//  NeteaseMusic
//
//  Created by xjbeta on 2019/4/9.
//  Copyright © 2019 xjbeta. All rights reserved.
//

import Cocoa
import PromiseKit

class PlaylistViewController: NSViewController {

    @IBOutlet weak var playAllButton: NSButton!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var coverImageView: NSImageView!
    @IBOutlet weak var titleTextFiled: NSTextField!
    @IBOutlet weak var playlistStrTextField: NSTextField!
    
    @IBOutlet weak var playCountTextField: NSTextField!
    @IBOutlet weak var trackCountTextField: NSTextField!
    @IBOutlet weak var descriptionTextField: NSTextField!
    
    @IBAction func playPlaylist(_ sender: Any) {
        let addTracks = tracks
        let ids = addTracks.map { $0.id }
        let clickedRow = tableView.clickedRow
        if PlayCore.shared.playlist.map({ $0.id }) == ids {
            if (sender as? NSButton) == playAllButton {
                PlayCore.shared.start()
            } else if (sender as? NSTableView) == tableView {
                PlayCore.shared.start(clickedRow)
            }
            return
        }
        
        PlayCore.shared.playlist = addTracks
        PlayCore.shared.api.songUrl(ids).done { [weak self] songs in
            guard PlayCore.shared.playlist == addTracks,
                songs.count == PlayCore.shared.playlist.count else { return }
            
            PlayCore.shared.playlist.enumerated().forEach { obj in
                PlayCore.shared.playlist[obj.offset].song = songs.first {
                    $0.id == obj.element.id
                }
            }
            
            if (sender as? NSButton) == self?.playAllButton {
                PlayCore.shared.start()
            } else if (sender as? NSTableView) == self?.tableView {
                PlayCore.shared.start(clickedRow)
            }
            }.catch {
                print($0)
        }
    }
    
    @IBAction func subscribe(_ sender: NSButton) {
        guard playlistId > 0 else { return }
        let id = playlistId
        sender.isEnabled = false
        PlayCore.shared.api.userPlaylist().then { playlists -> Promise<()> in
            let subscribedIds = playlists.filter {
                $0.subscribed
                }.map {
                    $0.id
            }
            
            if subscribedIds.contains(id) {
                return PlayCore.shared.api.playlistSubscribe(id, unSubscribe: true)
            } else {
                return PlayCore.shared.api.playlistSubscribe(id)
            }
            }.ensure(on: .main) {
                let todo = "Update sidebar"
                sender.isEnabled = true
            }.done {
                print("playlist subscribe / unsubscribe success")
            }.catch {
                print($0)
        }
    }
    
    @IBOutlet weak var topViewLayoutConstraint: NSLayoutConstraint!
//    var isUpdateLayout = false
    
    var sidebarItemObserver: NSKeyValueObservation?
    @objc dynamic var tracks = [Track]()
    var playlistId = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        playlistStrTextField.stringValue = "歌单"
        playlistStrTextField.textColor = .init(red: 0.83, green: 0.23, blue: 0.19, alpha: 1)
        playlistStrTextField.wantsLayer = true
        playlistStrTextField.layer?.borderWidth = 1
        playlistStrTextField.layer?.cornerRadius = 3.5
        playlistStrTextField.layer?.borderColor = .init(red: 0.83, green: 0.23, blue: 0.19, alpha: 1)
        
            
        sidebarItemObserver = ViewControllerManager.shared.observe(\.selectedSidebarItem, options: [.initial, .old, .new]) { [weak self] core, changes in
            guard let new = changes.newValue,
                new?.type == .playlist || new?.type == .favourite || new?.type == .discoverPlaylist,
                let id = new?.id else { return }
            self?.playlistId = id
            
            if id > 0 {
                self?.initPlaylist(id)
            } else if new?.title == "每日歌曲推荐", id == -1 {
                self?.initPlaylistWithRecommandSongs()
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(scrollViewDidScroll(_:)), name: NSScrollView.didLiveScrollNotification, object: tableView.enclosingScrollView)
    }
    
    func initPlaylistInfo() {
        coverImageView.image = nil
        titleTextFiled.stringValue = ""
        playCountTextField.integerValue = 0
        trackCountTextField.integerValue = 0
        descriptionTextField.stringValue = ""
        descriptionTextField.toolTip = ""
        tracks.removeAll()
    }
    
    func initPlaylist(_ id: Int) {
        initPlaylistInfo()
        PlayCore.shared.api.playlistDetail(id).done(on: .main) {
            guard self.playlistId == id else { return }
            
            self.coverImageView.image = NSImage(contentsOf: $0.coverImgUrl)
            self.titleTextFiled.stringValue = $0.name
            let descriptionStr = $0.description ?? "none"
            self.descriptionTextField.stringValue = descriptionStr
            self.descriptionTextField.toolTip = descriptionStr
            self.playCountTextField.integerValue = $0.playCount
            self.trackCountTextField.integerValue = $0.trackCount
            var tracks = $0.tracks ?? []
            tracks.enumerated().forEach {
                tracks[$0.offset].index = $0.offset
            }
            self.tracks = tracks
            }.catch {
                print($0)
        }
    }
    
    func initPlaylistWithRecommandSongs() {
        initPlaylistInfo()
        PlayCore.shared.api.recommendSongs().done(on: .main) {
            guard self.playlistId == -1 else { return }
            self.titleTextFiled.stringValue = "每日歌曲推荐"
            self.descriptionTextField.stringValue = "根据你的音乐口味生成, 每天6:00更新"
            var tracks = $0
            tracks.enumerated().forEach {
                tracks[$0.offset].index = $0.offset
            }
            self.tracks = tracks
            }.catch {
                print($0)
        }
    }
    
    @objc func scrollViewDidScroll(_ notification: Notification) {
        if let scrollView = notification.object as? NSScrollView {
            let visibleRect = scrollView.contentView.documentVisibleRect
//            self.topViewLayoutConstraint.constant = visibleRect.origin.y > 100 ? 100 : 200
//            isUpdateLayout = true
//            NSAnimationContext.runAnimationGroup({
//                $0.duration = 0.15
//                self.topViewLayoutConstraint.animator().constant = visibleRect.origin.y > 100 ? 100 : 200
//                isUpdateLayout = false
//            })
            
        }
    }
    
    deinit {
        sidebarItemObserver?.invalidate()
    }
}

