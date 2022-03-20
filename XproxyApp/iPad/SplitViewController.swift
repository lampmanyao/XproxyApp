//
//  SplitViewController.swift
//  Xproxy
//
//  Created by lampman on 2022/3/11.
//

import UIKit

class SplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    
	override func viewDidLoad() {
	    super.viewDidLoad()
        navigationItem.title = "Xproxy"
        preferredDisplayMode = .oneBesideSecondary
        splitViewController?.primaryBackgroundStyle = .none
        presentsWithGesture = false
	}
}
