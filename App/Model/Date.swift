//
//  Date.swift
//  Xproxy
//
//  Created by lampman on 12/15/24.
//

import Foundation

extension Date {
    func diff(from startDate: Self) -> String {
        let differenceInSeconds = Int(self.timeIntervalSince(startDate))
        let days = differenceInSeconds / (24 * 3600)
        let hours = (differenceInSeconds % (24 * 3600)) / 3600
        let minutes = (differenceInSeconds % 3600) / 60
        let seconds = differenceInSeconds % 60

        if days > 0 {
            return String(format: "%02d %02d:%02d:%02d", days, hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}
