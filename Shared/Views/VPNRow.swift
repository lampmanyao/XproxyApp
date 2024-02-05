//
//  VPNRow.swift
//  XproxyApp
//
//  Created by lampman on 2/1/24.
//

import SwiftUI

struct VPNRow: View {
    @Binding var selectedConfiguration: VPNConfiguration?
    @ObservedObject var configuration: VPNConfiguration

    @State private var hovered = false

    var body: some View {
        HStack(content: {
            Image(systemName: "network.badge.shield.half.filled")
                .foregroundColor(Defaults.shared.selectedVPN == configuration.address + ":" + configuration.port ? .orange : .gray)
            Button(action: {
                Defaults.shared.selectedVPN = configuration.address + ":" + configuration.port
                selectedConfiguration = configuration
            }, label: {
                HStack {
                    Text(configuration.name)
                        .foregroundColor(Defaults.shared.selectedVPN == configuration.address + ":" + configuration.port ? .orange : .gray)
                    Spacer()
                }
                .contentShape(Rectangle())
            })
            .buttonStyle(.borderless)
        })
        .padding(4.0)
        .background(hovered ? RoundedRectangle(cornerRadius: 7.5).fill(Color.blue.opacity(0.7)) : nil)
        .onHover(perform: { hovering in
            hovered.toggle()
        })
    }
}
