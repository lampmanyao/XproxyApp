//
//  ServerConfigurationView.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import SwiftUI
import NetworkExtension

struct ServerConfigurationView: View {

    @ObservedObject var xproxyVPNManager: XproxyVPNManager
    @ObservedObject private var serverConfiguration: ServerConfiguration

    @State private var status = false
    @State private var showAlert = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showPasswd: Bool = false

    @Environment(\.dismiss) private var dismiss

    init(_ xproxyVPNManager: XproxyVPNManager, serverConfiguration: ServerConfiguration) {
        self.xproxyVPNManager = xproxyVPNManager
        self.serverConfiguration = serverConfiguration
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Basic") {
                    HStack(alignment: .center) {
                        Text("Status:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("Status", isOn: $status)
                        #if os(iOS)
                            .onChange(of: status) { value in
                                if value {
                                    Task {
                                        do {
                                            try await self.serverConfiguration.startVPN()
                                        } catch let error {
                                            self.showAlert = true
                                            self.alertTitle = "Start VPN failed"
                                            self.alertMessage = error.localizedDescription
                                        }
                                    }
                                } else {
                                    self.serverConfiguration.stopVPN()
                                }
                            }
                            #else
                            .onChange(of: status) {
                                if status {
                                    Task {
                                        do {
                                            try await self.serverConfiguration.startVPN()
                                        } catch let error {
                                            self.showAlert = true
                                            self.alertTitle = "Start VPN failed"
                                            self.alertMessage = error.localizedDescription
                                        }
                                    }
                                } else {
                                    self.serverConfiguration.stopVPN()
                                }
                            }
                            #endif
                            .onAppear {
                                status = serverConfiguration.vpnManager.connection.status == .connected
                            }
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    HStack(alignment: .center) {
                        Text("Name:")
                            .foregroundStyle(.secondary)
                        TextField(text: $serverConfiguration.name, prompt: Text("Required")) {
                        }
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                        .labelsHidden()
                        .foregroundStyle(.primary)
                    }
                    
                    HStack(alignment: .center) {
                        Text("Address:")
                            .foregroundStyle(.secondary)
                        TextField(text: $serverConfiguration.address, prompt: Text("Required")) {
                        }
                        .multilineTextAlignment(.trailing)
                        .labelsHidden()
                        .foregroundStyle(.primary)
                    }
                    
                    HStack(alignment: .center) {
                        Text("Port:")
                            .foregroundStyle(.secondary)
                        TextField(text: $serverConfiguration.port, prompt: Text("Required")) {
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
                            TextField("Required", text: $serverConfiguration.password)
                                .labelsHidden()
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.primary)
                                .autocorrectionDisabled()
                        } else {
                            SecureField(text: $serverConfiguration.password, prompt: Text("Required")) {
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
                        
                        Picker("Method", selection: $serverConfiguration.method) {
                            ForEach(Constant.SupportMethods) { method in
                                Text(method).tag(method)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .headerProminence(.increased)

                Section {
                    HStack {
                        Text("Auto config")
                        Spacer()
                        Toggle("", isOn: $serverConfiguration.autoConfig)
                        .toggleStyle(.switch)
                    }
                } header: {
                    Text("Proxy Auto Config")
                }

                Section {
                    ForEach(serverConfiguration.exceptionList.indices, id: \.self) { idx in
                        TextField("Required", text: $serverConfiguration.exceptionList[idx])
                    }
                } header: {
                    HStack {
                        Text("Exclude domains")
                        Spacer()
                        Button {
                            serverConfiguration.delDomain()
                        } label: {
                            Image(systemName: "minus")
                        }
                        
                        Button {
                            serverConfiguration.addDomain("")
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                } footer: {
                    Text("This domains will not be routed to VPN server.")
                }
                .headerProminence(.increased)
                
                #if os(macOS)
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await xproxyVPNManager.remove(by: self.serverConfiguration)
                        }
                        dismiss()
                    } label: {
                        Text("Delete")
                            .frame(width: 60)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        save()
                        dismiss()
                    } label: {
                        Text("Save")
                            .frame(width: 60)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(6.0)
                #endif
            }
            #if os(iOS)
            .toolbar {
                Button {
                    save()
                    dismiss()
                } label: {
                    Text("Save")
                }
            }
            #endif
            .alert(alertTitle, isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .navigationTitle(serverConfiguration.name)
        }
    }

    private func save() {
        if let error = self.serverConfiguration.verify() {
            self.showAlert = true
            self.alertTitle = "Invalid Configuration."
            self.alertMessage = error.description
            return
        }

        let providerProtocol = NETunnelProviderProtocol()
        let providerConfiguration = serverConfiguration.configuration()
        providerProtocol.providerConfiguration = providerConfiguration
        providerProtocol.serverAddress = self.serverConfiguration.address

        self.serverConfiguration.vpnManager.isEnabled = true
        self.serverConfiguration.vpnManager.localizedDescription = serverConfiguration.name
        self.serverConfiguration.vpnManager.protocolConfiguration = providerProtocol
        self.serverConfiguration.vpnManager.saveToPreferences { error in
            if let saveError = error {
                self.showAlert = true
                self.alertTitle = "Save VPN Configuration Failed."
                self.alertMessage = saveError.localizedDescription
            }
        }
        self.xproxyVPNManager.addServerConfiguration(serverConfiguration)
    }
}
