//
//  AppDelegate.swift
//  XproxyApp
//
//  Created by lampman on 2/3/24.
//

#if os(macOS)

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        signals_init()
        coredump_init()
        crypt_setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        crypt_cleanup()
    }
}

#else

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    func applicationDidFinishLaunching(_ application: UIApplication) {
        signals_init()
        coredump_init()
        crypt_setup()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        crypt_cleanup()
    }
}
#endif
