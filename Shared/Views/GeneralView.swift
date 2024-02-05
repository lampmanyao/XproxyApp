//
//  GeneralView.swift
//  XproxyApp
//
//  Created by lampman on 1/29/24.
//

import SwiftUI

struct GeneralSettingsView: View {
    @StateObject var defaults = Defaults.shared
    @State private var port = Defaults.shared.localPort

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Start vpn after launched:")
                Spacer()
                Toggle("", isOn: $defaults.startVPN)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            HStack {
                Text("Stop vpn when quit:")
                Spacer()
                Toggle("", isOn: $defaults.stopVPN)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            HStack {
                Text("Local server port:")
                Spacer()
                TextField("", value: $port, formatter: NumberFormatter()) {
                    Defaults.shared.localPort = port
                }
                .frame(width: 60)
            }
        }
    }
}
