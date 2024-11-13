//
//  AppMenu.swift
//  XproxyApp
//
//  Created by lampman on 1/29/24.
//

import SwiftUI

struct AppMenu: View {
    @ObservedObject var xproxyVPNManager: XproxyVPNManager
    @Binding var selectedConfiguration: VPNConfiguration?
    @State var isConnected: Bool = false

    @Environment(\.openWindow) private var openWindow

    @State private var preferencesHovered = false
    @State private var serversHovered = false
    @State private var quitHovered = false

    var body: some View {
        VStack(alignment: .leading) {
            StatusView(vpnConfiguration: $selectedConfiguration, isConnected: $isConnected)
            Divider()

            if !xproxyVPNManager.configurations.isEmpty {
                Section {
                    List(xproxyVPNManager.configurations, selection: $selectedConfiguration) { configuration in
                        VPNRow(selectedConfiguration: $selectedConfiguration, configuration: configuration)
                    }
                    .background(.ultraThinMaterial)
                    .cornerRadius(10.0)
                    .listStyle(.sidebar)
                } header: {
                    Text("VPNs")
                        .fontWeight(.semibold)
                }
                .headerProminence(.increased)

                Divider()
            }

            Button(action: {
                openServers()
            }, label: {
                HStack {
                    Text("Servers ...")
                        .padding(.leading, 4)
                    Spacer()
                    Image(systemName: "command")
                        .foregroundStyle(.secondary)
                    Text("S")
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .contentShape(Rectangle())
            })
            .background(serversHovered ? RoundedRectangle(cornerRadius: 7.5).fill(Color.blue.opacity(0.7)) : nil)
            .buttonStyle(.borderless)
            .keyboardShortcut("s")
            .onHover(perform: { hovering in
                self.serversHovered.toggle()
            })
            Divider()

            SettingsLink {
                HStack {
                    Text("Preferences ...")
                        .padding(.leading, 4)
                    Spacer()
                    Image(systemName: "command")
                        .foregroundStyle(.secondary)
                    Text(",")
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .contentShape(Rectangle())
            }
            .contentShape(Rectangle())
            .background(preferencesHovered ? RoundedRectangle(cornerRadius: 7.5).fill(Color.blue.opacity(0.7)) : nil)
            .buttonStyle(.borderless)
            .onHover(perform: { hovering in
                self.preferencesHovered.toggle()
            })
            Divider()

            Button(action: quitApp, label: {
                HStack {
                    Text("Quit")
                        .padding(.leading, 4)
                    Spacer()
                    Image(systemName: "command")
                        .foregroundStyle(.secondary)
                    Text("Q")
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .contentShape(Rectangle())
            })
            .background(quitHovered ? RoundedRectangle(cornerRadius: 7.5).fill(Color.blue.opacity(0.7)) : nil)
            .buttonStyle(.borderless)
            .keyboardShortcut("q")
            .onHover(perform: { hovering in
                self.quitHovered.toggle()
            })
        }
        .onChange(of: selectedConfiguration, {
            isConnected = selectedConfiguration?.manager?.connection.status == .connected
        })
        .padding()
    }

    func openServers() {
        openWindow(id: "Xproxy")
    }

    func quitApp() {
        if Defaults.shared.stopVPN {
            xproxyVPNManager.stop(selectedConfiguration)
        }
        NSApp.terminate(self)
    }
}
