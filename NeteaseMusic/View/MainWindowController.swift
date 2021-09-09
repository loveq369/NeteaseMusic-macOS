//
//  MainWindowController.swift
//  NeteaseMusic
//
//  Created by xjbeta on 2019/4/9.
//  Copyright © 2019 xjbeta. All rights reserved.
//

import Cocoa
import PromiseKit

class MainWindowController: NSWindowController {
    var updateLoginStatusObserver: NSObjectProtocol?
    var initSidebarPlaylistsObserver: NSObjectProtocol?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.isMovableByWindowBackground = true
        
        updateLoginStatusObserver = NotificationCenter.default.addObserver(forName: .updateLoginStatus, object: nil, queue: .main) { _ in
            self.test()
        }
        initSidebarPlaylistsObserver = NotificationCenter.default.addObserver(forName: .initSidebarPlaylists, object: nil, queue: .main) { _ in
            self.initSidebarPlaylists()
        }
        
        test()
        
    }
    
    func test() {
        guard let vc = self.contentViewController as? MainViewController,
              let discoverVC = vc.contentTabVC(.discover),
              let sidebarVC = sidebarVC(),
              let loginVC = loginVC()
        else { return }
        
        when(fulfilled: [
            discoverVC.initContent(),
            sidebarVC.updatePlaylists()
        ]).done {
            vc.updateMainTabView(.main)
            
            
            print("123  init")
        }.catch(on: .main) {
            switch $0 {
            case NeteaseMusicAPI.RequestError.errorCode((let code, let string)):
                if code == 301 {
                    print("should login.")
                    vc.updateMainTabView(.login)
                    loginVC.initViews()
                } else {
                    print(code, string)
                }
            default:
                print($0)
            }
        }
    }
    
    func initSidebarPlaylists() {
        guard let sidebarVC = sidebarVC() else { return }
        sidebarVC.updatePlaylists().done {
            
        }.catch {
            print($0)
        }
    }
    
    func sidebarVC() -> SidebarViewController? {
        guard let vc = contentViewController as? MainViewController else { return nil }
        return vc.children.compactMap({ $0 as? SidebarViewController }).first
    }
    
    func loginVC() -> LoginViewController? {
        guard let vc = contentViewController as? MainViewController else { return nil }
        return vc.children.compactMap({ $0 as? LoginViewController }).first
    }
    
    deinit {
        if let o = updateLoginStatusObserver {
            NotificationCenter.default.removeObserver(o)
        }
        if let o = initSidebarPlaylistsObserver {
            NotificationCenter.default.removeObserver(o)
        }
    }
}
