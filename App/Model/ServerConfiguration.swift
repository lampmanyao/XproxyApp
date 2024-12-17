//
//  ServerConfiguration.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import SwiftUI
import NetworkExtension

class ServerConfiguration: ObservableObject, Identifiable, Hashable {
    @Published var vpnManager: NEVPNManager
    @Published var name: String
    @Published var address: String
    @Published var port: String
    @Published var password: String
    @Published var method: String
    @Published var autoConfig: Bool
    @Published var exceptionList: [String]
    @Published var isConnected: Bool = false

    init(vpnManager: NEVPNManager,
         name: String,
         address: String,
         port: String,
         password: String,
         method: String = "aes-256-cfb",
         autoConfig: Bool = false,
         exceptionList: [String] = []) {
        self.vpnManager = vpnManager
        self.name = name
        self.address = address
        self.port = port
        self.password = password
        self.method = method
        self.autoConfig = autoConfig
        self.exceptionList = exceptionList
        self.isConnected = vpnManager.connection.status == .connected
    }

    func configuration() -> [String: Any]? {
        var conf: [String : Any] = [:]
        conf["name"] = name
        conf["address"] = address
        conf["port"] = port
        conf["password"] = password
        conf["method"] = method
        conf["autoConfig"] = autoConfig
        conf["exceptionList"] = exceptionList.filter { $0 != "" }
        return conf
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

    func startVPN() async throws {
        self.vpnManager.isEnabled = true
        try await self.vpnManager.saveToPreferences()
        try await self.vpnManager.loadFromPreferences()
        try self.vpnManager.connection.startVPNTunnel()
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }

    func stopVPN() {
        self.vpnManager.connection.stopVPNTunnel()
        self.isConnected = false
    }

    func addDomain(_ domain: String) {
        exceptionList.append(domain)
    }

    func delDomain() {
        if !exceptionList.isEmpty {
            exceptionList.removeLast()
        }
    }

    func description() -> String {
        return "{name: \(name), address: \(address), port: \(port), password: \(password), method: \(method)}"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ServerConfiguration, rhs: ServerConfiguration) -> Bool {
        return lhs.address == rhs.address && lhs.port == rhs.port
    }
}
