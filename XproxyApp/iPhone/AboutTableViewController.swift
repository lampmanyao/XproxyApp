//
//  AboutTableViewController.swift
//  Xproxy
//
//  Created by lampman on 2022/3/12.
//

import UIKit

class AboutTableViewController: UITableViewController {

	@IBOutlet weak var opensslVersionLabel: UILabel!
	@IBOutlet weak var opensslBuiltOnLabel: UILabel!
	
    override func viewDidLoad() {
        super.viewDidLoad()

		navigationItem.title = "About"
		
		if UIDevice.current.userInterfaceIdiom == .pad {
			navigationItem.hidesBackButton = true
		}
		
		let opensslVersionStr = String(cString: openssl_version())
		let arr1 = opensslVersionStr.components(separatedBy: " ")
		opensslVersionLabel.text = arr1[0] + " " + arr1[1]
		
		let builtOnStr = String(cString: openssl_built_on())
		let arr2 = builtOnStr.components(separatedBy: ": ")
		opensslBuiltOnLabel.text = arr2[1]
    }
	
	class func instance() -> AboutTableViewController {
		let storyboard = UIStoryboard(name: "iPhone", bundle: nil)
		let vc = storyboard.instantiateViewController(withIdentifier: "AboutTableViewController") as! AboutTableViewController
		return vc
	}

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
}
