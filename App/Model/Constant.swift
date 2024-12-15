//
//  Constant.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import Foundation

struct Constant {
    static let SupportMethods: [String] = ["aes-256-cfb", "aes-192-cfb", "aes-128-cfb"]
}

extension String: @retroactive Identifiable {
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}
