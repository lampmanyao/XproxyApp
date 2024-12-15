//
//  Integer.swift
//  Xproxy
//
//  Created by lampman on 12/15/24.
//


extension UInt64 {
    private enum TrafficUnit: UInt64 {
        case byte = 1
        case kb = 1024
        case mb = 1_048_576
        case gb = 1_073_741_824
        case tb = 1_099_511_627_776
    }

    func trafficFormatted() -> String {
        if self < TrafficUnit.kb.rawValue {
            return "\(self) Bytes"
        } else if self < TrafficUnit.mb.rawValue {
            return String(format: "%.2f KB", Double(self) / Double(TrafficUnit.kb.rawValue))
        } else if self < TrafficUnit.gb.rawValue {
            return String(format: "%.2f MB", Double(self) / Double(TrafficUnit.mb.rawValue))
        } else if self < TrafficUnit.tb.rawValue {
            return String(format: "%.2f GB", Double(self) / Double(TrafficUnit.gb.rawValue))
        } else {
            return String(format: "%.2f TB", Double(self) / Double(TrafficUnit.tb.rawValue))
        }
    }
}
