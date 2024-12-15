//
//  XproxyApp.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import SwiftUI

@main
struct XproxyApp: App {
    @ApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @ObservedObject var xproxyVPNManager = XproxyVPNManager()

    var body: some Scene {
#if os(macOS)
        MenuBarExtra("Xproxy", image: "StatusBarIcon", content: {
            AppMenu(xproxyVPNManager: xproxyVPNManager)
                .frame(width: 300)
        })
        .menuBarExtraStyle(.window)
#endif

        #if os(macOS)
        WindowGroup(for: ContentView.Group.self) { $selectedGroup in
            ContentView(xproxyVPNManager, selectedGroup: selectedGroup)
                .frame(minWidth: 700, maxWidth: 700,
                       minHeight: 400, maxHeight: 400)
        } defaultValue: {
            ContentView.groups[0]
        }
        .windowResizability(.contentSize)
        #else
        WindowGroup(for: ContentView.Group.self) { $selectedGroup in
            ContentView(xproxyVPNManager, selectedGroup: selectedGroup)
                .onAppear {
                    FileManager.createSharedFiles()
                    TrafficReader.shared.setupSharedMemory()
                }
        } defaultValue: {
            ContentView.groups[0]
        }
        #endif
        
    }
}
