//
//  FileManager+Extension.swift
//  Xproxy
//
//  Created by lampman on 2022/3/25.
//

import Foundation

extension FileManager {
    static var appGroupId: String? {
		let appGroupIdInfoDictionaryKey = "group.com.lampmanyao.Xproxy"
		return appGroupIdInfoDictionaryKey
    }
	
    private static var sharedFolderURL: URL? {
		guard let appGroupId = FileManager.appGroupId else {
			return nil
		}
		guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
			return nil
		}
		return sharedFolderURL
    }

    static var trafficFileURL: URL? {
		return sharedFolderURL?.appendingPathComponent("traffic.data")
    }

    static func deleteFile(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            return false
        }
        return true
    }
}
