//
//  PreferencesView.swift
//  XproxyApp
//
//  Created by lampman on 1/29/24.
//

import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag("general")
        }
        .padding(16)
        .frame(width: 300, height: 100)
    }
}
