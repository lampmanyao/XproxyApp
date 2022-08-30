//
//  Double+Extension.swift
//  Xproxy
//
//  Created by lampman on 2022/8/30.
//

import Foundation

extension Double {
    func toSize() -> String {
        if self >= 1024 * 1024 * 1024.0 {
            let l = self / 1024.0 / 1024.0 / 1024.0
            return String(format: "%.1f GiB", l)
        } else if self >= 1024 * 1024.0 {
            let l = self / 1024.0 / 1024.0
            return String(format: "%.1f MiB", l)
        } else if self >= 1024.0 {
            let l = self / 1024.0
            return String(format: "%.1f KiB", l)
        } else {
            return String(format: "%.2f B", self)
        }
    }
}
