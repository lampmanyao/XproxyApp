//
//  ConfiurationError.swift
//  XproxyApp
//
//  Created by lampman on 2/5/24.
//


enum ConfigurationError: Int32, Error {
    case emptyName
    case emptyAddress
    case invalidPort
    case emptyPassword
    case unknown
}

extension ConfigurationError: CustomStringConvertible {
    var description: String {
        switch self {
        case .emptyName: return "Name is empty."
        case .emptyAddress: return "Address is empty."
        case .invalidPort: return "Port is invalid."
        case .emptyPassword: return "Password is empty."
        case .unknown: return "Unknown"
        }
    }
}
