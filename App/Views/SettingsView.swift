//
//  SettingsView.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import SwiftUI

struct SettingsView: View {

    @State private var localPort: Int = Defaults.shared.localPort

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Local proxy port: ")
                        Spacer()
                        TextField("local port", value: $localPort, format: PortNumberFormatter())
                            #if os(macOS)
                            .onChange(of: localPort) {
                                Defaults.shared.localPort = localPort
                            }
                            #else
                            .onChange(of: localPort, perform: { _ in
                                Defaults.shared.localPort = localPort
                            })
                            #endif
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Local proxy")
                } footer: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.yellow)
                        Text("If you change the port number, you must change the port number in the config.pac file, Or the auto config won't work!")
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section {
                    NavigationLink("config.pac", destination: {
                        PacView()
                    })
                } header: {
                    HStack {
                        Text("Proxy configuration file")
                        Spacer()
                        Button {
                            do {
                                try FileManager.resetPACFile()
                            } catch let error {
                                self.showAlert = true
                                self.alertTitle = "Reset pac file failed"
                                self.alertMessage = error.localizedDescription
                            }
                        } label: {
                            Text("Reset")
                        }
                    }
                }

                Section(header: Text("About")) {
                    VStack {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(self.version())
                        }
                        Divider()
                        HStack {
                            Text("Build")
                            Spacer()
                            Text(self.buildNumber())
                        }
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .navigationTitle("Settings")
        }
    }

    func version() -> String {
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        return version
    }

    func buildNumber() -> String {
        let dictionary = Bundle.main.infoDictionary!
        let build = dictionary["CFBundleVersion"] as! String
        return build
    }
}
