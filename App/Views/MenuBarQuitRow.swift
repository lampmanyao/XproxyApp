//
//  MenuBarQuitRow.swift
//  Xproxy
//
//  Created by lampman on 12/17/24.
//

import SwiftUI

#if os(macOS)
struct MenuBarQuitRow: View {
    @State private var hovered = false

    var body: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            HStack(alignment: .center) {
                Text("Quit")
                    .padding(.leading, 4)
                Spacer()
                Image(systemName: "command")
                    .resizable()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(.gray)
                Text("Q")
                    .padding(.trailing, 4)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 30)
        .background(hovered ? .purple.opacity(0.6) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 5.0))
        .keyboardShortcut("s", modifiers: [.command])
        .onHover { isHovered in
            self.hovered = isHovered
        }
    }
}
#endif
