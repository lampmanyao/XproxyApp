//
//  MenuBarVPNRow.swift
//  Xproxy
//
//  Created by lampman on 12/12/24.
//

import SwiftUI

#if os(macOS)
struct MenuBarVPNRow: View {
    @ObservedObject var serverConfigutaion: ServerConfiguration
    @State private var isOn = false

    var body: some View {
        HStack {
            Text(serverConfigutaion.name)
                .padding(.leading, 4)
            Spacer()

            Toggle(isOn: $isOn) {

            }
            .padding(.trailing, 4)
            .toggleStyle(.switch)
            .onChange(of: isOn) {
                if isOn {
                    Task {
                        try? await serverConfigutaion.startVPN()
                    }
                } else {
                    serverConfigutaion.stopVPN()
                }
            }
            .onChange(of: serverConfigutaion.isConnected) {
                self.isOn = serverConfigutaion.isConnected
            }
        }
    }
}
#endif
