//
//  XproxyVPNManager.swift
//  Xproxy
//
//  Created by lampman on 1/25/24.
//

import SwiftUI

@preconcurrency
import NetworkExtension

class XproxyVPNManager: ObservableObject {
    @Published var configurations: [ServerConfiguration] = []
    @Published var connectedVPNManager: NEVPNManager?

    init() {
        Task {
            await loadVPNPerferences()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: nil, queue: .main) { notification in
            if let session = notification.object as? NETunnelProviderSession {
                self.updateConnectedVPNManagerIfPossible(session: session)
            }
        }
    }

    @MainActor
    private func loadVPNPerferences() async {
        configurations.removeAll()
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            for manager in managers {
                if manager.connection.status == .connected {
                    connectedVPNManager = manager
                }
                if let conf = (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration {
                    let configuration = ServerConfiguration(
                        vpnManager: manager,
                        name: conf["name"] as! String,
                        address: conf["address"] as! String,
                        port: conf["port"] as! String,
                        password: conf["password"] as! String,
                        method: conf["method"] as! String,
                        autoConfig: conf["autoConfig"] as! Bool,
                        exceptionList: conf["exceptionList"] as! [String]
                    )
                    self.configurations.append(configuration)
                }
            }
        } catch let error {
            print("Load vpn preferences error: \(error.localizedDescription)")
        }
    }

    private func updateConnectedVPNManagerIfPossible(session: NETunnelProviderSession) {
        var found = false
        for configuration in configurations {
            if let conf = (session.manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration {
                let address = conf["address"] as! String
                let port = conf["port"] as! String

                if address == configuration.address && port == configuration.port {
                    if session.manager.connection.status == .connected {
                        connectedVPNManager = configuration.vpnManager
                        configuration.isConnected = true
                        found = true
                    } else {
                        configuration.isConnected = false
                    }
                } else {
                    configuration.isConnected = false
                }
            }
        }

        if !found {
            connectedVPNManager = nil
        }
    }

    @MainActor
    func addServerConfiguration(_ serverConfiguration: ServerConfiguration) {
        for configuration in configurations {
            if configuration == serverConfiguration {
                return
            }
        }
        configurations.append(serverConfiguration)
    }

    @MainActor
    func remove(by serverConfiguration: ServerConfiguration?) async {
        guard let configuration = serverConfiguration else { return }
        do {
            try await configuration.vpnManager.removeFromPreferences()
            if let idx = self.configurations.firstIndex(of: configuration) {
                self.configurations.remove(at: idx)
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }

    @MainActor
    func remove(atOffsets: IndexSet) {
        let configs = atOffsets.map{ configurations[$0] }
        for config in configs {
            config.vpnManager.removeFromPreferences()
        }
        configurations.remove(atOffsets: atOffsets)
    }
}
