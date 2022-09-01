//
//  String+Extension.swift
//  Xproxy
//
//  Created by lampman on 2022/9/1.
//

import Foundation
import UIKit

extension String {
    func attributedString(color: UIColor) -> NSMutableAttributedString {
        let str = NSMutableAttributedString.init(string: self)
        str.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: self.count))
        return str
    }
}
