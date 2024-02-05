//
//  VPNConfiguration.swift
//  XproxyApp
//
//  Created by lampman on 1/20/24.
//

import SwiftUI
import NetworkExtension

class VPNConfiguration: ObservableObject, Identifiable, Hashable {
    @Published var manager: NEVPNManager?
    @Published var name: String = ""
    @Published var address: String = ""
    @Published var port: String = ""
    @Published var password: String = ""
    @Published var method: String = "aes-256-cfb"
    @Published var exceptionList: [String] = []

    init(
        manager: NEVPNManager? = nil,
        name: String,
        address: String,
        port: String,
        password: String,
        method: String,
        exceptionList: [String] = [],
        includedRoutesV4: [NEIPv4Route] = [],
        excludedRoutesV4: [NEIPv4Route] = []
    ) {
        self.manager = manager
        self.name = name
        self.address = address
        self.port = port
        self.password = password
        self.method = method
        self.exceptionList = exceptionList
    }

    func configuration() -> [String : Any]? {
        var conf: [String : Any] = [:]
        conf["name"] = name
        conf["address"] = address
        conf["port"] = port
        conf["password"] = password
        conf["method"] = method
        conf["exceptionList"] = exceptionList.filter { $0 != "" }
        return conf
    }

    func toString() -> String {
        return "{name: \(name), address: \(address), port: \(port), password: \(password), method: \(method)}"
    }

    func addDomain(_ domain: String) {
        exceptionList.append(domain)
    }

    func delDomain() {
        if !exceptionList.isEmpty {
            exceptionList.removeLast()
        }
    }

    func verify() -> ConfigurationError? {
        if name.isEmpty {
            return .emptyName
        }

        if address.isEmpty {
            return .emptyAddress
        }

        if port.isEmpty || UInt16(port) == nil {
            return .invalidPort
        }

        if password.isEmpty {
            return .emptyPassword
        }

        return nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VPNConfiguration, rhs: VPNConfiguration) -> Bool {
        return lhs.name == rhs.name && lhs.address == rhs.address && lhs.port == rhs.port
    }
}
