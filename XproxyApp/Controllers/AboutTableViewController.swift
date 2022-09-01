//
//  AboutTableViewController.swift
//  Xproxy
//
//  Created by lampman on 2022/3/12.
//

import UIKit

class AboutTableViewController: UITableViewController {

    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var builtLabel: UILabel!
    @IBOutlet weak var githubLabel: UILabel!
	@IBOutlet weak var opensslVersionLabel: UILabel!
	@IBOutlet weak var opensslBuiltOnLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

		navigationItem.title = "About"
		
		if UIDevice.current.userInterfaceIdiom == .pad {
			navigationItem.hidesBackButton = true
		}
        
        versionLabel.text = Bundle.main.releaseVersionNumber
        builtLabel.text = Bundle.main.buildVersionNumber
        
        let string = NSMutableAttributedString.init(string: "")
        string.append(Constant.githubLink.attributedString(color: .systemBlue))
        githubLabel.attributedText = string
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(labelTapped))
        githubLabel.addGestureRecognizer(tapGesture)
        githubLabel.isUserInteractionEnabled = true
        
		let opensslVersionStr = String(cString: openssl_version())
		let arr1 = opensslVersionStr.components(separatedBy: " ")
		opensslVersionLabel.text = arr1[0] + " " + arr1[1]
		
		let builtOnStr = String(cString: openssl_built_on())
		let arr2 = builtOnStr.components(separatedBy: ": ")
		opensslBuiltOnLabel.text = arr2[1]
    }
    
    class func instance() -> Self {
        let storyboard = UIStoryboard(name: "AboutTableViewController", bundle: nil)
        return storyboard.instantiateInitialViewController() as! Self
    }
	
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 3 : 2
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    
    @objc private func labelTapped(gesture: UITapGestureRecognizer) {
        let url = URL(string: "https://" + Constant.githubLink)!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
