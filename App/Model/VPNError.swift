//
//  VPNError.swift
//  XproxyApp
//
//  Created by lampman on 2022/3/25.
//

enum VPNError: Int32, Error {
    case unsupportMethod
    case maxOpenFiles
    case addressInUse
    case system
    case invalidConfigure
    case unknown
}

extension VPNError: CustomStringConvertible {
    var description: String {
        switch self {
        case .unsupportMethod: return "Unsupport method"
        case .maxOpenFiles: return "Cann't set max open files"
        case .addressInUse: return "Address is in use"
        case .system: return "System error"
        case .invalidConfigure: return "Invalid configure"
        case .unknown: return "Unknown"
        }
    }
}
