//
//  ServersView.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import SwiftUI
import NetworkExtension

struct ServersView: View {
    @ObservedObject var xproxyVPNManager: XproxyVPNManager

    @State private var showSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(xproxyVPNManager.configurations) { configuration in
                    NavigationLink {
                        ServerConfigurationView(xproxyVPNManager, serverConfiguration: configuration)
                    } label: {
                        Text(configuration.name)
                            .font(.headline)
                            .frame(height: 40)
                    }
                }
                .onDelete(perform: { at in
                    xproxyVPNManager.remove(atOffsets: at)
                })
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .toolbar {
                ToolbarItem {
                    Button {
                        showSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSheet) {
                let configuration = ServerConfiguration(vpnManager: NETunnelProviderManager(),
                                                        name: "New Server",
                                                        address: "",
                                                        port: "",
                                                        password: "",
                                                        method: "aes-256-cfb",
                                                        exceptionList: [])
                ServerConfigurationView(xproxyVPNManager, serverConfiguration: configuration)
                #if os(macOS)
                    .frame(width: 600, height: 400)
                #endif
            }
            .navigationTitle("Servers")
        }
    }
}
