//
//  ContentView.swift
//  XproxyApp
//
//  Created by lampman on 1/23/24.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var xproxyVPNManager: XproxyVPNManager
    @State var selectedConfiguration: VPNConfiguration?

    @State var showAlert = false
    @State var alertTitle = ""
    @State var alertMessage = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedConfiguration) {
                ForEach(xproxyVPNManager.configurations, id: \.self) { configuration in
                    VPNRow(selectedConfiguration: $selectedConfiguration, configuration: configuration)
                        #if os(iOS)
                        .listRowBackground(
                            self.selectedConfiguration == configuration ? RoundedRectangle(cornerRadius: 7.5).fill(Color.orange.opacity(0.5)) : nil
                        )
                        #endif
                        .contextMenu {
                            if configuration.manager?.connection.status == .connected {
                                Button(action: {
                                    configuration.manager?.connection.stopVPNTunnel()
                                }, label: {
                                    Text("Disconnect")
                                })
                            } else if configuration.manager?.connection.status == .disconnected {
                                Button(action: {
                                    if !configuration.manager!.isEnabled {
                                        configuration.manager?.isEnabled = true
                                        configuration.manager?.saveToPreferences { error in
                                            if let saveError = error {
                                                showAlert = true
                                                alertTitle = "Start VPN Failed."
                                                alertMessage = saveError.localizedDescription
                                                return
                                            }
                                            do {
                                                try configuration.manager?.connection.startVPNTunnel()
                                            } catch {
                                                showAlert = true
                                                alertTitle = "Start VPN Failed."
                                                alertMessage = error.localizedDescription
                                            }
                                        }
                                    } else {
                                        do {
                                            try configuration.manager?.connection.startVPNTunnel()
                                        } catch {
                                            showAlert = true
                                            alertTitle = "Start VPN Failed."
                                            alertMessage = error.localizedDescription
                                        }
                                    }
                                }, label: {
                                    Text("Connect")
                                })
                            }

                            Button(action: {
                                Task {
                                    await xproxyVPNManager.delete(by: configuration)
                                    selectedConfiguration = nil
                                    await xproxyVPNManager.loadVPNPerferences()
                                }
                            }, label: {
                                Text("Delete")
                            })
                        }
                        .alert(alertTitle, isPresented: $showAlert) {
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text(alertMessage)
                        }
                }
            }
            .toolbar {
                Button(action: {
                    selectedConfiguration = xproxyVPNManager.newVPNConfiguration()
                }, label: {
                    Image(systemName: "plus")
                })
            }
            .navigationTitle("Xproxy")
            .navigationSplitViewColumnWidth(240)
        } detail: {
            if let selected = selectedConfiguration {
                VPNConfigurationView(vpnConfiguration: selected)
            }
        }
    }
}
