//
//  MenuBarSettingsRow.swift
//  Xproxy
//
//  Created by lampman on 12/16/24.
//

import SwiftUI

struct MenuBarSettingsRow: View {
    @State private var hovered = false

    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button {
            openWindow(value: ContentView.groups[2])
        } label: {
            HStack(alignment: .center) {
                Text("Settings")
                    .padding(.leading, 4)
                Spacer()
                Image(systemName: "command")
                    .resizable()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(.gray)
                Text("P")
                    .padding(.trailing, 4)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 30)
        .background(hovered ? .purple.opacity(0.6) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5.0))
        .keyboardShortcut("p", modifiers: [.command])
        .onHover { isHovered in
            self.hovered = isHovered
        }
    }
}
