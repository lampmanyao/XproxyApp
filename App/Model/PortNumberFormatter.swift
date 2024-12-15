//
//  PortNumberFormatter.swift
//  Xproxy
//
//  Created by lampman on 12/15/24.
//

import SwiftUI

struct PortNumberParseStrategy: ParseStrategy {
    typealias ParseInput = String
    typealias ParseOutput = Int

    func parse(_ value: String) throws -> Int {
        guard let number = Int(value), number >= 1024 && number <= 65535 else {
            throw NSError(domain: "PortNumberParseStrategy", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid port number"])
        }
        return number
    }
}

class PortNumberFormatter: Formatter, ParseableFormatStyle {
    typealias Strategy = PortNumberParseStrategy
    typealias FormatInput = Int
    typealias FormatOutput = String

    var parseStrategy: PortNumberParseStrategy

    override init() {
        self.parseStrategy = PortNumberParseStrategy()
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func string(for object: Any?) -> String? {
        guard let number = object as? Int else { return nil }
        if number >= 1024 && number <= 65535 {
            return String(number)
        } else {
            return nil
        }
    }

    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        guard let number = Int(string) else { return false }
        if number >= 1024 && number <= 65535 {
            obj?.pointee = NSNumber(value: number) as AnyObject
            return true
        } else {
            return false
        }
    }

    func format(_ value: Int) -> String {
        String(value)
    }
}
