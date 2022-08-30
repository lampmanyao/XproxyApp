//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by lampman on 2022/3/9.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var localProxyAddress = "127.0.0.1"
    private var localProxyPort = 8080
    
    private var timer: Timer?
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        
        guard let conf = (protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration else {
            completionHandler(TunnelError.invalidConfigure)
            return
        }
        
        let address = conf["address"] as! String
        let port = conf["port"] as! String
        let method = conf["method"] as! String
        let password = conf["password"] as! String
        let exceptionList = conf["exceptionList"] as! [String]
        
        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "172.20.10.25")
        networkSettings.mtu = 1500
        
        let ipv4Settings = NEIPv4Settings(addresses: ["172.20.10.25"], subnetMasks: ["255.255.255.0"])
        let proxySettings = NEProxySettings()
        // set the http proxy
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: localProxyAddress, port: localProxyPort)
        // set the https proxy
        proxySettings.httpsEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: localProxyAddress, port: localProxyPort)
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
            
            let err = start_local_proxy(address, UInt16(port)!, password, method)
            if err == ERR_NONE {
                completionHandler(nil)
            } else if err == ERR_UNSUPPORT_METHOD {
                completionHandler(TunnelError.unsupportMethod)
            } else if err == ERR_MAX_OPENFILES {
                completionHandler(TunnelError.maxOpenFiles)
            } else if err ==  ERR_ADDRESS_IN_USE {
                completionHandler(TunnelError.addressInUse)
            } else if err == ERR_SYSTEM {
                completionHandler(TunnelError.system)
            } else {
                completionHandler(TunnelError.unknown)
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
