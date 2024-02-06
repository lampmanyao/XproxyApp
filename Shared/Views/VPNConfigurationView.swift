//
//  VPNView.swift
//  XproxyApp
//
//  Created by lampman on 1/20/24.
//

import SwiftUI
import NetworkExtension

struct VPNConfigurationView: View {
    @ObservedObject var vpnConfiguration: VPNConfiguration
    @State private var isOn: Bool = false

    @State private var showAlert = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showPasswd: Bool = false

    var body: some View {
        List {
            Section("Basic") {
                if let manager = vpnConfiguration.manager {
                    HStack(alignment: .center) {
                        Text("Status:")
                            .foregroundStyle(.secondary)

                        Spacer()

                        Toggle("Status", isOn: $isOn)
                            .onAppear {
                                isOn = vpnConfiguration.manager?.connection.status == .connected
                            }
                            .onChange(of: isOn, perform: { value in
                                if value {
                                    if !manager.isEnabled {
                                        manager.isEnabled = true
                                        manager.saveToPreferences { error in
                                            if let saveError = error {
                                                showAlert = true
                                                alertTitle = "Save VPN Configuration Failed."
                                                alertMessage = saveError.localizedDescription
                                            } else {
                                                startVPN(manager)
                                            }
                                        }
                                    } else {
                                        startVPN(manager)
                                    }
                                } else {
                                    manager.connection.stopVPNTunnel()
                                }
                            })
                    }
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                HStack(alignment: .center) {
                    Text("Name:")
                        .foregroundStyle(.secondary)
                    TextField(text: $vpnConfiguration.name, prompt: Text("Required")) {
                    }
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .labelsHidden()
                    .foregroundStyle(.primary)
                }

                HStack(alignment: .center) {
                    Text("Address:")
                        .foregroundStyle(.secondary)
                    TextField(text: $vpnConfiguration.address, prompt: Text("Required")) {
                    }
                    .multilineTextAlignment(.trailing)
                    .labelsHidden()
                    .foregroundStyle(.primary)
                }

                HStack(alignment: .center) {
                    Text("Port:")
                        .foregroundStyle(.secondary)
                    TextField(text: $vpnConfiguration.port, prompt: Text("Required")) {
                    }
                    .autocorrectionDisabled()
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
                }

                HStack(alignment: .center) {
                    Text("Password:")
                        .foregroundStyle(.secondary)
                    if showPasswd {
                        TextField("Required", text: $vpnConfiguration.password)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.primary)
                            .autocorrectionDisabled()
                    } else {
                        SecureField(text: $vpnConfiguration.password, prompt: Text("Required")) {
                        }
                        .autocorrectionDisabled()
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.primary)
                    }

                    Button(action: {
                        showPasswd.toggle()
                    }) {
                        Image(systemName: self.showPasswd ? "eye" : "eye.slash")
                            .accentColor(.gray)
                    }
                }

                HStack(alignment: .center) {
                    Text("Method:")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("Method", selection: $vpnConfiguration.method) {
                        ForEach(Constant.SupportMethods) { method in
                            Text(method).tag(method)
                        }
                    }
                    .labelsHidden()
                }
            }
            .headerProminence(.increased)

            Section {
                ForEach(vpnConfiguration.exceptionList.indices, id: \.self) { idx in
                    TextField("Required", text: $vpnConfiguration.exceptionList[idx])
                }
            } header: {
                HStack {
                    Text("Exclude domains")
                    Spacer()
                    Button {
                        vpnConfiguration.delDomain()
                    } label: {
                        Image(systemName: "minus")
                    }

                    Button {
                        vpnConfiguration.addDomain("")
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            } footer: {
                Text("This domains will not be routed to VPN server.")
            }
            .headerProminence(.increased)
        }
        .environment(\.defaultMinListRowHeight, 35)
        .onChange(of: vpnConfiguration, perform: { value in
            isOn = vpnConfiguration.manager?.connection.status == .connected
        })
        .toolbar {
            Button("Save", action: {
                if let error = vpnConfiguration.verify() {
                    showAlert = true
                    alertTitle = "Invalid Configuration."
                    alertMessage = error.description
                    return
                }

                let providerProtocol = NETunnelProviderProtocol()
                let providerConfiguration = vpnConfiguration.configuration()
                providerProtocol.providerConfiguration = providerConfiguration
                providerProtocol.serverAddress = vpnConfiguration.address
                vpnConfiguration.manager!.isEnabled = true
                vpnConfiguration.manager!.localizedDescription = "Xproxy"
                vpnConfiguration.manager!.protocolConfiguration = providerProtocol
                vpnConfiguration.manager!.saveToPreferences { error in
                    if let saveError = error {
                        showAlert = true
                        alertTitle = "Save VPN Configuration Failed."
                        alertMessage = saveError.localizedDescription
                    }
                }
            })
            .alert(alertTitle, isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .navigationTitle(vpnConfiguration.name)
    }

    func startVPN(_ manager: NEVPNManager) {
        do {
            try manager.connection.startVPNTunnel()
        } catch let error {
            showAlert = true
            alertTitle = "Start VPN Failed."
            alertMessage = error.localizedDescription
        }
    }
}
