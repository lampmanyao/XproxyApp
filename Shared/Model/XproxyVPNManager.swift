//
//  XproxyVPNManager.swift
//  Xproxy
//
//  Created by lampman on 1/25/24.
//

import Foundation
import NetworkExtension

class XproxyVPNManager: ObservableObject {
    @Published var configurations: [VPNConfiguration] = []

    @MainActor
    func loadVPNPerferences() async {
        configurations.removeAll()
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            for manager in managers {
                if let conf = (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration {
                    let vpnConfiguration = VPNConfiguration(
                        manager: manager,
                        name: conf["name"] as! String,
                        address: conf["address"] as! String,
                        port: conf["port"] as! String,
                        password: conf["password"] as! String,
                        method: conf["method"] as! String,
                        exceptionList: conf["exceptionList"] as! [String]
                    )
                    self.configurations.append(vpnConfiguration)
                }
            }
        } catch let error {
            print(error.localizedDescription)
        }
    }

    func start(_ configuration: VPNConfiguration?) {
        do {
            try configuration?.manager?.connection.startVPNTunnel()
        } catch let error {
            print("Can not start VPN: \(error.localizedDescription)")
        }
    }

    func stop(_ configuration: VPNConfiguration?) {
        configuration?.manager?.connection.stopVPNTunnel()
    }

    func newVPNConfiguration() -> VPNConfiguration {
        let vpnConfiguration = VPNConfiguration(
            manager: NETunnelProviderManager(),
            name: "New VPN",
            address: "",
            port: "",
            password: "",
            method: "aes-256-cfb",
            exceptionList: []
        )
        configurations.append(vpnConfiguration)
        return vpnConfiguration
    }

    func delete(by vpnConfiguration: VPNConfiguration?) async {
        guard let vpnConfiguration = vpnConfiguration else { return }
        if let manager = vpnConfiguration.manager {
            do {
                try await manager.removeFromPreferences()
                if let idx = self.configurations.firstIndex(of: vpnConfiguration) {
                    self.configurations.remove(at: idx)
                }

                configurations = []
                await loadVPNPerferences()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
}
