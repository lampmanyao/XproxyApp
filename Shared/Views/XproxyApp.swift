//
//  XproxyApp.swift
//  XproxyApp
//
//  Created by lampman on 1/23/24.
//

import SwiftUI

@main
struct XproxyApp: App {

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @ObservedObject var xproxyVPNManager: XproxyVPNManager = XproxyVPNManager()
    @State var selectedConfiguration: VPNConfiguration?

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra("Xproxy", image: "status", content: {
            AppMenu(xproxyVPNManager: xproxyVPNManager, selectedConfiguration: $selectedConfiguration)
                .frame(width: 300)
                .task {
                    await xproxyVPNManager.loadVPNPerferences()
                    for configuration in xproxyVPNManager.configurations {
                        if Defaults.shared.selectedVPN == configuration.address + ":" + configuration.port {
                            selectedConfiguration = configuration
                        }
                    }
                    if selectedConfiguration == nil {
                        selectedConfiguration = xproxyVPNManager.configurations.first
                    }
                }
        })
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
        }

        Window("Xproxy", id: "Xproxy", content: {
            ContentView(xproxyVPNManager: xproxyVPNManager, selectedConfiguration: nil)
        })

        #else
        WindowGroup(id: "Xproxy", content: {
            ContentView(xproxyVPNManager: xproxyVPNManager, selectedConfiguration: nil)
                .task {
                    await xproxyVPNManager.loadVPNPerferences()
                }
        })
        #endif
    }
}
