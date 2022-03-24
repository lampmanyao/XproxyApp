//
//  UIViewController+Extension.swift
//  Xproxy
//
//  Created by lampman on 2022/3/24.
//

import UIKit

extension UIViewController {
	func presentError(_ title: String? = nil, _ message: String) {
		let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alertVC.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
		self.present(alertVC, animated: true, completion: nil)
	}
}
