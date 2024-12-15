//
//  Defaults.swift
//  XproxyApp
//
//  Created by lampman on 1/29/24.
//

import SwiftUI

class Defaults: ObservableObject {

    static public var shared = Defaults()

    @AppStorage("port", store: UserDefaults(suiteName: Bundle.groupid))
    public var localPort: Int = 1081

    @AppStorage("autoConfig", store: UserDefaults(suiteName: Bundle.groupid))
    public var autoConfig: Bool = false
}
