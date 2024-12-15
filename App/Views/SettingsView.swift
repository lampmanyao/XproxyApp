//
//  SettingsView.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import SwiftUI

struct SettingsView: View {

    @State private var localPort: Int = Defaults.shared.localPort
    @State private var autoConfig = Defaults.shared.autoConfig

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

                Section(header: Text("Proxy Auto Config")) {
                    HStack {
                        Text("Auto config")
                        Spacer()
                        Toggle(isOn: $autoConfig) {
                        }
                        .toggleStyle(.switch)
                        #if os(iOS)
                        .onChange(of: autoConfig, perform: { _ in
                            Defaults.shared.autoConfig = autoConfig
                        })
                        #else
                        .onChange(of: autoConfig) {
                            Defaults.shared.autoConfig = autoConfig
                        }
                        #endif
                    }

                    if autoConfig {
                        HStack {
                            NavigationLink("config.pac", destination: {
                                PacView()
                            })
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
