//
//  Defaults.swift
//  XproxyApp
//
//  Created by lampman on 1/29/24.
//

import SwiftUI

class Defaults: ObservableObject {

    static public var shared = Defaults()

    @AppStorage("startVPN")
    public var startVPN = false

    @AppStorage("stopVPN")
    public var stopVPN = true

    @AppStorage("port")
    public var localPort: Int = 8080

    @AppStorage("selectedVPN")
    public var selectedVPN: String = ""
}
