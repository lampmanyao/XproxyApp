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

    static var sharedPacURL: URL? {
        var pacURL: URL? = nil
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Bundle.groupid) {
            pacURL = containerURL.appending(path: "Library/Caches/config.pac")
        }
        return pacURL
    }

    static func createSharedFiles() {
        create_shared_file(FileManager.sharedSentPath)
        create_shared_file(FileManager.sharedRecvPath)
    }

    static func copyBuiltinPACFile() {
        let fileManager = FileManager.default
        let bundle = Bundle.main
        if let srcURL = bundle.url(forResource: "config", withExtension: "pac") {
            if let dstURL = self.sharedPacURL {
                if !fileManager.fileExists(atPath: dstURL.path()) {
                    do {
                        try fileManager.copyItem(at: srcURL, to: dstURL)
                    } catch let error {
                        print("coyp file error: \(error)")
                    }
                } else {
                    print("file exist")
                }
            }
        }
    }

    static func resetPACFile() throws {
        let fileManager = FileManager.default
        let bundle = Bundle.main
        if let srcURL = bundle.url(forResource: "config", withExtension: "pac") {
            if let dstURL = self.sharedPacURL {
                do {
                    try fileManager.removeItem(at: dstURL)
                    try fileManager.copyItem(at: srcURL, to: dstURL)
                } catch let error {
                    throw error
                }
            }
        }
    }
}
