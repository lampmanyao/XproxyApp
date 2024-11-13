//
//  Constant.swift
//  XproxyApp
//
//  Created by lampman on 2022/3/18.
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
