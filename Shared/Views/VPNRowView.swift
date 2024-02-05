//
//  VPNRowView.swift
//  Xproxy_iOS
//
//  Created by lampman on 1/24/24.
//

import SwiftUI

struct VPNRowView: View {
    @State private var isSelected = false
    var name: String

    var body: some View {
        HStack {
            Toggle(isOn: $isSelected, label: {
                Text(name)
                    .fontWeight(.medium)
            })
            .toggleStyle(.automatic)
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        VPNRowView(name: "New VPN")
    }
}
