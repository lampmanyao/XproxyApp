//
//  PacView.swift
//  Xproxy
//
//  Created by lampman on 12/15/24.
//

import SwiftUI

struct PacView: View {

    @State private var text: String = ""

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .cornerRadius(4.0)
                .padding()
                .navigationTitle("config.pac")
        }
        .onAppear {
            if let pacURL = Bundle.main.url(forResource: "config", withExtension: "pac") {
                do {
                    self.text = try String(contentsOf: pacURL, encoding: .utf8)
                } catch let error {
                    self.showAlert = true
                    self.alertTitle = "Open pac file failed"
                    self.alertMessage = error.localizedDescription
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    if let pacURL = Bundle.main.url(forResource: "config", withExtension: "pac") {
                        try? text.write(to: pacURL, atomically: true, encoding: .utf8)
                    }
                } label: {
                    Text("Save")
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }

    }
}
