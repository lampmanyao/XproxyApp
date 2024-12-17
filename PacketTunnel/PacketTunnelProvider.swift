//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by lampman on 12/9/24.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {

    let logger = Logger(subsystem: "com.lampmanyao.Xproxy", category: "PacketTunnel")

    private func readPACFile() -> String? {
        var content: String?
        if let pacURL = FileManager.sharedPacURL {
            do {
                content = try String(contentsOf: pacURL, encoding: .utf8)
            } catch let error {
                content = nil
                logger.error("Cannot read config.pac file with error:\(error.localizedDescription)")
            }
        }
        return content
    }

    private var localProxyAddress = "127.0.0.1"
    private var localProxyPort: Int = Defaults.shared.localPort
    private var timer: Timer?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let conf = (protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration else {
            completionHandler(VPNError.invalidConfigure)
            logger.error("Invalid configuration")
            return
        }

        let remoteProxyAddress = conf["address"] as! String
        let remoteProxyPort = conf["port"] as! String
        let method = conf["method"] as! String
        let password = conf["password"] as! String
        let autoConfig = conf["autoConfig"] as! Bool
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

        if (autoConfig) {
            if let js = readPACFile() {
                proxySettings.autoProxyConfigurationEnabled = true
                proxySettings.proxyAutoConfigurationJavaScript = js
            }

            // FIXME: - don't know why this doesn't work.
//            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.groupid) {
//                let pacURL = containerURL.appending(path: "Library/Caches/config.pac")
//                proxySettings.autoProxyConfigurationEnabled = true
//                proxySettings.proxyAutoConfigurationURL = pacURL
//            }
        } else {
            logger.debug("autoConfig disabled")
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
                self.logger.error("Unsupport method")
            } else if err == ERR_MAX_OPENFILES {
                completionHandler(VPNError.maxOpenFiles)
                self.logger.error("Max open files")
            } else if err ==  ERR_ADDRESS_IN_USE {
                completionHandler(VPNError.addressInUse)
                self.logger.error("Address in used")
            } else if err == ERR_SYSTEM {
                completionHandler(VPNError.system)
                self.logger.error("System")
            } else {
                completionHandler(VPNError.unknown)
                self.logger.error("Unknown")
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
