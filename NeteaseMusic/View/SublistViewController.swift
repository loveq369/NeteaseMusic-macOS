//
//  SublistViewController.swift
//  NeteaseMusic
//
//  Created by xjbeta on 2019/12/11.
//  Copyright © 2019 xjbeta. All rights reserved.
//

import Cocoa

class SublistViewController: NSViewController {
    @IBOutlet weak var segmentedControl: NSSegmentedControl!
    @IBOutlet weak var containerView: NSView!
    @IBAction func actions(_ sender: NSSegmentedControl) {
        initContent()
    }
    
    var sidebarItemObserver: NSKeyValueObservation?
    
    lazy var menuContainer: (menu: NSMenu?, menuController: TAAPMenuController?) = {
        var objects: NSArray?
        Bundle.main.loadNibNamed(.init("TAAPMenu"), owner: nil, topLevelObjects: &objects)
        let mc = objects?.compactMap {
            $0 as? TAAPMenuController
        }.first
        let m = objects?.compactMap {
            $0 as? NSMenu
        }.first
        return (m, mc)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initContent()
        albumArtistTableVC()?.menu = menuContainer.menu
        sidebarItemObserver = ViewControllerManager.shared.observe(\.selectedSidebarItem, options: [.initial, .old, .new]) { core, changes in
            guard let newType = changes.newValue??.type,
                newType != changes.oldValue??.type,
                newType == .mySubscription else { return }
            
            self.initContent()
            
        }
    }
    
    func initContent() {
        containerView.isHidden = true
        guard let vc = albumArtistTableVC() else { return }
        let api = PlayCore.shared.api
        vc.tableView.menu = menuContainer.menu
        menuContainer.menuController?.delegate = self
        
        switch segmentedControl.selectedSegment {
        case 0:
            vc.resetData(.album, responsiveScrolling: true)
            api.albumSublist().done(on: .main) {
                self.containerView.isHidden = $0.count == 0
                vc.albums = $0
                vc.reloadTableView()
            }.catch {
                print($0)
            }
        case 1:
            vc.resetData(.artist, responsiveScrolling: true)
            api.artistSublist().done(on: .main) {
                self.containerView.isHidden = $0.count == 0
                vc.artists = $0
                vc.reloadTableView()
            }.catch {
                print($0)
            }
        default:
            return
        }
    }
    
    func albumArtistTableVC() -> AlbumArtistTableViewController? {
        let vc = children.compactMap {
            $0 as? AlbumArtistTableViewController
            }.first
        return vc
    }
    
    deinit {
        sidebarItemObserver?.invalidate()
    }
}

extension SublistViewController: TAAPMenuDelegate {
    func selectedItems() -> (id: [Int], items: [Any]) {
        guard let vc = albumArtistTableVC() else {
            return ([], [])
        }
        switch vc.dataType {
        case .album:
            let items = vc.albums.enumerated().filter {
                vc.tableView.selectedIndexs().contains($0.offset)
            }.map {
                $0.element
            }
            return (items.map({ $0.id }), items)
        case .artist:
            let items = vc.artists.enumerated().filter {
                vc.tableView.selectedIndexs().contains($0.offset)
            }.map {
                $0.element
            }
            return (items.map({ $0.id }), items)
        default:
            return ([], [])
        }
    }
    
    func presentNewPlaylist(_ newPlaylisyVC: NewPlaylistViewController) {
        guard newPlaylisyVC.presentingViewController == nil else { return }
        self.presentAsSheet(newPlaylisyVC)
    }
    
    func removeSuccess(ids: [Int], newItem: Any?) {
        guard let vc = albumArtistTableVC() else {
            return
        }
        switch vc.dataType {
        case .album:
            vc.albums.removeAll {
                ids.contains($0.id)
            }
        case .artist:
            vc.artists.removeAll {
                ids.contains($0.id)
            }
        default:
            return
        }
    }
    
    func shouldReloadData() {
        initContent()
    }
    
    func tableViewList() -> (type: SidebarViewController.ItemType, id: Int, contentType: TAAPItemsType) {
        guard let vc = albumArtistTableVC() else {
            return (.none, 0, .none)
        }
        return (.mySubscription, 0, vc.dataType)
    }
}
