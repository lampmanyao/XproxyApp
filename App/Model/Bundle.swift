//
//  Bundle.swift
//  Xproxy
//
//  Created by lampman on 12/15/24.
//

import Foundation

extension Bundle {
    static var groupid: String {
    #if os(macOS)
        "KMX6B9L26T.group.com.lampmanyao.Xproxy"
    #else
        "group.com.lampmanyao.Xproxy"
    #endif
    }
}
