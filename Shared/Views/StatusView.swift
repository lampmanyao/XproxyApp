//
//  StatusView.swift
//  XproxyApp
//
//  Created by lampman on 1/29/24.
//

import SwiftUI

struct StatusView: View {
    @Binding var vpnConfiguration: VPNConfiguration?
    @Binding var isConnected: Bool

    @State private var status: String = "Invalid"
    @State private var vpnName: String = "No selected vpn server"
    @State private var hovered = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Status")
                    .fontWeight(.bold)
                Spacer()
                Text(status)
            }

            HStack {
                Text(vpnName)
                Spacer()
                if vpnConfiguration != nil {
                    Toggle("", isOn: $isConnected)
                        .onChange(of: isConnected, {
                            if isConnected {
                                start()
                            } else {
                                stop()
                            }
                        })
                        .toggleStyle(.switch)
                } else {
                    Toggle("", isOn: $isConnected)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(true)
                }
            }
            .padding(4.0)
            .background(.ultraThinMaterial)
            .cornerRadius(10.0)
            .background(hovered ? RoundedRectangle(cornerRadius: 10.0).fill(Color.blue.opacity(0.7)) : nil)
            .onHover(perform: { hovering in
                hovered.toggle()
            })
        }
        .onChange(of: vpnConfiguration, {
            if vpnConfiguration != nil {
                vpnName = vpnConfiguration!.name
                if vpnConfiguration?.manager?.connection.status == .connected {
                    status = "Connected"
                } else {
                    status = "Disconnected"
                }
            }
        })
        .onAppear {
            observeVpnStatus()
        }
    }

    func start() {
        if let manager = vpnConfiguration?.manager {
            do {
                try manager.connection.startVPNTunnel()
            } catch {
                isConnected = false
            }
        }
    }

    func stop() {
        vpnConfiguration?.manager?.connection.stopVPNTunnel()
    }

    private func observeVpnStatus() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NEVPNStatusDidChange,
            object: self.vpnConfiguration?.manager?.connection,
            queue: OperationQueue.main, using: { notification in
                guard let status = self.vpnConfiguration?.manager?.connection.status else {
                    return
                }

                switch status {
                case .invalid:
                    self.status = "invalid"
                    self.isConnected = false

                case .disconnected:
                    self.status = "Disconnected"
                    self.isConnected = false

                case .connecting:
                    self.status = "Connecting"
                    self.isConnected = true

                case .connected:
                    self.status = "Connected"
                    self.isConnected = true

                case .reasserting:
                    self.status = "Reasserting"
                    self.isConnected = false

                case .disconnecting:
                    self.status = "Disconnecting"
                    self.isConnected = false

                @unknown default:
                    break
                }
            }
        )
    }
}
