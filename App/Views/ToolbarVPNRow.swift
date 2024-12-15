//
//  ToolbarVPNRow.swift
//  Xproxy
//
//  Created by lampman on 12/14/24.
//

import SwiftUI

struct ToolbarVPNRow: View {
    @ObservedObject var serverConfigutaion: ServerConfiguration
    @State private var isOn = false

    var body: some View {
        Button {
            if serverConfigutaion.isConnected {
                serverConfigutaion.stopVPN()
            } else {
                Task {
                    try? await serverConfigutaion.startVPN()
                }
            }
        } label: {
            VStack {
                Text(serverConfigutaion.name)
                Spacer()
                if serverConfigutaion.isConnected {
                    Image(systemName: "checkmark")
                }
            }
        }
        #if os(iOS)
        .onChange(of: serverConfigutaion.isConnected, perform: { _ in
            self.isOn = serverConfigutaion.isConnected
        })
        #else
        .onChange(of: serverConfigutaion.isConnected) {
            self.isOn = serverConfigutaion.isConnected
        }
        #endif
    }
}
