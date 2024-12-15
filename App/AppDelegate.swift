//
//  AppDelegate.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import SwiftUI

#if os(macOS)

import AppKit
typealias XProxyAppDelegate = NSApplicationDelegate
typealias XProxyApplication = NSApplication
typealias ApplicationDelegateAdaptor = NSApplicationDelegateAdaptor
typealias AppArgType = Notification

#else

import UIKit
typealias XProxyAppDelegate = UIApplicationDelegate
typealias XProxyApplication = UIApplication
typealias ApplicationDelegateAdaptor = UIApplicationDelegateAdaptor
typealias AppArgType = UIApplication

#endif

class AppDelegate: NSObject, XProxyAppDelegate {
    func applicationDidFinishLaunching(_ arg: AppArgType) {
        FileManager.createSharedFiles()
        TrafficReader.shared.setupSharedMemory()
    }

    func applicationWillTerminate(_ arg: AppArgType) {
    }
}
