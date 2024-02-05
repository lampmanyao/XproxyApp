//
//  PacketTunnelProvider.swift
//  macOSPacketTunnel
//
//  Created by lampman on 1/31/24.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var localAddress = "127.0.0.1"
    private var localPort: Int = Defaults.shared.localPort
    private var timer: Timer?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {

        guard let conf = (protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration else {
            completionHandler(VPNError.invalidConfigure)
            return
        }

        let serverAddress = conf["address"] as! String
        let serverPort = conf["port"] as! String
        let method = conf["method"] as! String
        let password = conf["password"] as! String
        let exceptionList = conf["exceptionList"] as! [String]

        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "172.20.10.25")
        networkSettings.mtu = 1500

        let ipv4Settings = NEIPv4Settings(addresses: ["172.20.10.25"], subnetMasks: ["255.255.255.0"])
        let proxySettings = NEProxySettings()

        // set the http proxy
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: localAddress, port: localPort)

        // set the https proxy
        proxySettings.httpsEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: localAddress, port: localPort)

        // exception list
        proxySettings.matchDomains = [""]
        proxySettings.exceptionList = exceptionList

        networkSettings.proxySettings = proxySettings
        networkSettings.ipv4Settings = ipv4Settings

        setTunnelNetworkSettings(networkSettings) { error in
            guard error == nil else {
                completionHandler(error)
                return
            }

            let err = start_local_proxy(self.localAddress, UInt16(self.localPort), serverAddress, UInt16(serverPort)!, password, method)

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
        if let handler = completionHandler {
            handler(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }

    override func wake() {
        // Add code here to wake up.
    }
}
