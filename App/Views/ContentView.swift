//
//  ContentView.swift
//  Xproxy
//
//  Created by lampman on 12/9/24.
//

import SwiftUI

struct ContentView: View {
    
    struct Group: Identifiable, Hashable, Decodable, Encodable {
        var id = UUID()
        let name: String
        let image: String
    }

    static let groups = [
        Group(name: "Status", image: "gauge.with.dots.needle.bottom.50percent"),
        Group(name: "Servers", image: "server.rack"),
        Group(name: "Settings", image: "gear")
    ]

    @ObservedObject var xproxyVPNManager: XproxyVPNManager

    #if os(macOS)
    @State private var selectedGroup: Group
    #else
    @State private var selectedGroup: Group?
    #endif

    init(_ xproxyVPNManager: XproxyVPNManager, selectedGroup: Group) {
        self.xproxyVPNManager = xproxyVPNManager
        self.selectedGroup = selectedGroup
    }

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                List(selection: $selectedGroup) {
                    ForEach(Self.groups, id: \.self) { group in
                        HStack {
                            Image(systemName: group.image)
                                .resizable()
                                .frame(width: 18, height: 18)

                            Text(group.name)
                        }
                        .padding(.all, 10)
                    }
                }
                .onAppear {
                    selectedGroup = Self.groups[0]
                }
                .navigationTitle("Xproxy")
            } detail: {
                if selectedGroup?.name == Self.groups[0].name {
                    StatusView(xproxyVPNManager: xproxyVPNManager)
                } else if selectedGroup?.name == Self.groups[1].name {
                    ServersView(xproxyVPNManager: xproxyVPNManager)
                } else {
                    SettingsView()
                }
            }
        } else {
            TabView {
                StatusView(xproxyVPNManager: xproxyVPNManager)
                    .tabItem {
                        Label(Self.groups[0].name, systemImage: Self.groups[0].image)
                    }

                ServersView(xproxyVPNManager: xproxyVPNManager)
                    .tabItem {
                        Label(Self.groups[1].name, systemImage: Self.groups[1].image)
                    }

                SettingsView()
                    .tabItem {
                        Label(Self.groups[2].name, systemImage: Self.groups[2].image)
                    }
            }
        }
        #else
        NavigationSplitView {
            List(selection: $selectedGroup) {
                ForEach(Self.groups, id: \.self) { group in
                    HStack {
                        Image(systemName: group.image)
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(group.name)
                    }
                    .padding(.all, 10)
                }
            }

            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .navigationTitle("Xproxy")
        } detail: {
            if selectedGroup.name == Self.groups[0].name {
                StatusView(xproxyVPNManager: xproxyVPNManager)
            } else if selectedGroup.name == Self.groups[1].name {
                ServersView(xproxyVPNManager: xproxyVPNManager)
            } else {
                SettingsView()
            }
        }
        #endif
    }
}
