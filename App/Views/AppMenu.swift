//
//  AppMenu.swift
//  Xproxy
//
//  Created by lampman on 12/12/24.
//

import SwiftUI
import NetworkExtension

#if os(macOS)
struct AppMenu: View {
    @ObservedObject var xproxyVPNManager: XproxyVPNManager

    @State private var connectedTime: String = "00:00:00"

    let timer = Timer.publish(every: 1, on: .current, in: .common).autoconnect()

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading) {
            GroupBox {
                if let vpnManager = xproxyVPNManager.connectedVPNManager {
                    VStack {
                        HStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 10, height: 10)
                            Text("Status")
                                .fontWeight(.semibold)
                            Spacer()
                            switch vpnManager.connection.status {
                            case .invalid:
                                Text("Invalid")
                            case .disconnected:
                                Text("Disconnected")
                            case .connecting:
                                Text("Connecting")
                            case .connected:
                                Text("Connected")
                            case .reasserting:
                                Text("Reasseting")
                            case .disconnecting:
                                Text("Disconnecting")
                            default:
                                Text("Unknown")
                            }
                        }
                        .padding(4)

                        Divider()

                        HStack {
                            Text("Connected time:")
                                .font(.headline)
                            Spacer()
                            Text(connectedTime)
                                .onReceive(timer, perform: { _ in
                                    self.connectedTime = Date.now.diff(from: vpnManager.connection.connectedDate!)
                                })
                        }
                        .padding(4)

                        HStack {
                            Text("Connected at:")
                                .font(.headline)
                            Spacer()
                            Text(vpnManager.connection.connectedDate!.formatted())
                        }
                        .padding(4)
                    }
                } else {
                    HStack(alignment: .center) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("Status")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Disconnected")
                    }
                    .padding(4)

                    Divider()

                    HStack {
                        Text("Connected time:")
                            .font(.headline)
                        Spacer()
                        Text("--:--:--")
                    }
                    .padding(4)
                        
                    HStack {
                        Text("Connected at:")
                            .font(.headline)
                        Spacer()
                        Text("Invalid")
                    }
                    .padding(4)
                }
            }

            Divider()

            Button("Servers") {
                openWindow(value: ContentView.groups[1])
            }
            .buttonStyle(.plain)
            .keyboardShortcut("S")
            .padding(.leading, 0)
            .padding(.top, 4)
            .padding(.bottom, 4)
            .keyboardShortcut("s", modifiers: [.command])

            List {
                ForEach(xproxyVPNManager.configurations) { configuration in
                    MenuVPNRow(serverConfigutaion: configuration)
                }
                .listRowSeparator(.hidden)
            }

            Divider()
            Button("Settings") {
                openWindow(value: ContentView.groups[2])
            }
            .buttonStyle(.plain)
            .keyboardShortcut("S")
            .padding(.leading, 0)
            .padding(.top, 4)
            .padding(.bottom, 4)
            .keyboardShortcut("p", modifiers: [.command])

            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .padding(.leading, 0)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        .padding()
    }
}
#endif
