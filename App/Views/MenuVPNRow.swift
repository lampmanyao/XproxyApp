//
//  MenuVPNRow.swift
//  Xproxy
//
//  Created by lampman on 12/12/24.
//

import SwiftUI

#if os(macOS)
struct MenuVPNRow: View {
    @ObservedObject var serverConfigutaion: ServerConfiguration
    @State private var isOn = false

    var body: some View {
        HStack {
            Text(serverConfigutaion.name)
            Spacer()

            Toggle(isOn: $isOn) {

            }
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
        .padding(.init(top: 0, leading: 4, bottom: 4, trailing: 0))
    }
}
#endif
