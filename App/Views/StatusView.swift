//
//  StatusView.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import SwiftUI
import NetworkExtension

struct StatusView: View {

    @ObservedObject var xproxyVPNManager: XproxyVPNManager

    @State private var sentBytes: UInt64 = 0
    @State private var recvBytes: UInt64 = 0

    @State private var connectedTime: String = "00:00:00"

    let connectedTimeTimer = Timer.publish(every: 1, on: .current, in: .common).autoconnect()
    let sentBytesTimer = Timer.publish(every: 1, on: .current, in: .common).autoconnect()
    let recvBytesTimer = Timer.publish(every: 1, on: .current, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            GroupBox {
                VStack {
                    #if os(iOS)
                    Divider()
                    #endif
                    if let vpnManager = xproxyVPNManager.connectedVPNManager {
                        HStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 10, height: 10)
                            Text("Status:")
                                .font(.headline)
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

                        Divider()

                        HStack {
                            Text("Connected time:")
                                .font(.headline)
                            Spacer()
                            Text(connectedTime)
                                .onReceive(connectedTimeTimer, perform: { _ in
                                    self.connectedTime = Date.now.diff(from: vpnManager.connection.connectedDate!)
                                })
                        }

                        Divider()
                        HStack {
                            Text("Connected at:")
                                .font(.headline)
                            Spacer()
                            Text(vpnManager.connection.connectedDate!.formatted())
                        }
                    } else {
                        HStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                            Text("Status:")
                                .font(.headline)
                            Spacer()
                            Text("Disconnected")
                        }

                        Divider()

                        HStack {
                            Text("Connected time:")
                                .font(.headline)
                            Spacer()
                            Text("--:--:--")
                        }

                        Divider()
                        HStack {
                            Text("Connected at:")
                                .font(.headline)
                            Spacer()
                            Text("Invalid")
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "network")
                        .resizable()
                        .frame(width: 15, height: 15)
                    Text("VPN Status")
                        .font(Font.system(size: 15))
                }
            }
            .padding(EdgeInsets(top: 10, leading: 16, bottom: 4, trailing: 16))

            GroupBox {
                VStack {
                    #if os(iOS)
                    Divider()
                    #endif
                    HStack {
                        Text("Sent Bytes:")
                        Spacer()
                        Text(sentBytes.trafficFormatted())
                            .onReceive(sentBytesTimer, perform: { _ in
                                sentBytes = TrafficReader.shared.sentBytes()
                            })
                    }

                    Divider()
                    HStack {
                        Text("Received Bytes:")
                        Spacer()
                        Text(recvBytes.trafficFormatted())
                            .onReceive(recvBytesTimer, perform: { _ in
                                recvBytes = TrafficReader.shared.recvBytes()
                            })
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .resizable()
                        .frame(width: 15, height: 15)
                    Text("Traffic")
                        .font(Font.system(size: 15))
                }
            }
            .padding(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            Spacer()

            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ForEach(xproxyVPNManager.configurations) { configuration in
                            ToolbarVPNRow(serverConfigutaion: configuration)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }

            .navigationTitle("Status")
        }
    }
}
