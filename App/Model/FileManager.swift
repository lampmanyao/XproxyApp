//
//  FileManager.swift
//  Xproxy
//
//  Created by lampman on 12/13/24.
//

extension FileManager {

    static var sharedSentPath: String {
        var path = ""
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.groupid) {
            path = containerURL.appendingPathComponent("sent_bytes", conformingTo: .data).relativePath
        }
        return path
    }

    static var sharedRecvPath: String {
        var path: String = ""
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.groupid) {
            path = containerURL.appendingPathComponent("recv_bytes", conformingTo: .data).relativePath
        }
        return path
    }

    static func createSharedFiles() {
        create_shared_file(FileManager.sharedSentPath)
        create_shared_file(FileManager.sharedRecvPath)
    }
}
