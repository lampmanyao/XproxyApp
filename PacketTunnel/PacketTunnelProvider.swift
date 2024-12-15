//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by lampman on 12/9/24.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    private func readPACFile() -> String? {
        let bundle = Bundle.main
        let pacFilePath = bundle.path(forResource: "config", ofType: "pac")

        if let pacFilePath = pacFilePath {
            do {
                let pacFileData = try Data(contentsOf: URL(fileURLWithPath: pacFilePath))
                return String(data: pacFileData, encoding: .utf8)
            } catch {
                print("Read config.pac error: \(error)")
            }
        } else {
            print("config.pac not exist")
        }
        return nil
    }

    private var localProxyAddress = "127.0.0.1"
    private var localProxyPort: Int = Defaults.shared.localPort
    private var timer: Timer?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let conf = (protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration else {
            completionHandler(VPNError.invalidConfigure)
            return
        }

        let remoteProxyAddress = conf["address"] as! String
        let remoteProxyPort = conf["port"] as! String
        let method = conf["method"] as! String
        let password = conf["password"] as! String
        let exceptionList = conf["exceptionList"] as! [String]

        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")
        networkSettings.mtu = 1500

        // set the http proxy
        let proxySettings = NEProxySettings()
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: localProxyAddress, port: localProxyPort)

        // set the https proxy
        proxySettings.httpsEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: localProxyAddress, port: localProxyPort)

        proxySettings.matchDomains = [""]
        proxySettings.exceptionList = exceptionList

        if (Defaults.shared.autoConfig) {
            if let js = readPACFile() {
                proxySettings.autoProxyConfigurationEnabled = true
                proxySettings.proxyAutoConfigurationJavaScript = js
            }

            // FIXME: - don't know why this doesn't work.
//            if let filePath = Bundle.main.path(forResource: "config", ofType: "pac") {
//                let fileURL = URL(fileURLWithPath: filePath)
//                proxySettings.autoProxyConfigurationEnabled = true
//                proxySettings.proxyAutoConfigurationURL = fileURL
//            }
        }

        networkSettings.proxySettings = proxySettings

        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        networkSettings.ipv4Settings = ipv4Settings

        setTunnelNetworkSettings(networkSettings) { error in
            guard error == nil else {
                completionHandler(error)
                return
            }

            let err = start_local_proxy(self.localProxyAddress,
                                        UInt16(self.localProxyPort),
                                        remoteProxyAddress,
                                        UInt16(remoteProxyPort)!,
                                        password, method,
                                        FileManager.sharedSentPath, FileManager.sharedRecvPath)

            if err == ERR_NONE {
                completionHandler(nil)
            } else if err == ERR_UNSUPPORT_METHOD {
                completionHandler(VPNError.unsupportMethod)
            } else if err == ERR_MAX_OPENFILES {
                completionHandler(VPNError.maxOpenFiles)
            } else if err ==  ERR_ADDRESS_IN_USE {
                completionHandler(VPNError.addressInUse)
            } else if err == ERR_SYSTEM {
                completionHandler(VPNError.system)
            } else {
                completionHandler(VPNError.unknown)
            }
        }

    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        stop_local_proxy()
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        print(#function)
        if let handler = completionHandler {
            handler(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        print(#function)
        completionHandler()
    }

    override func wake() {
        print(#function)
    }
}
