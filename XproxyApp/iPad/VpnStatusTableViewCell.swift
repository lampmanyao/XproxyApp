//
//  VpnStatusTableViewCell.swift
//  Xproxy
//
//  Created by lampman on 2022/3/12.
//

import UIKit
import NetworkExtension

class VpnStatusTableViewCell: UITableViewCell {

	@IBOutlet weak var spinner: UIActivityIndicatorView!
	@IBOutlet weak var statusLabel: UILabel!
	@IBOutlet weak var toggle: UISwitch!
	
	var manager: NEVPNManager?
	
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
	
	func observeVpnStatus() {
		NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange,
											   object: self.manager?.connection,
											   queue: OperationQueue.main, using: { notification in
			guard let status = self.manager?.connection.status else {
				return
			}
			
			switch status {
			case .invalid:
				self.toggle.isEnabled = true
				self.toggle.isOn = false

				self.spinner.stopAnimating()
				self.statusLabel.text = "Invalid"
			case .disconnected:
				self.toggle.isEnabled = true
				self.toggle.isOn = false

				self.spinner.stopAnimating()
				self.statusLabel.text = "Disconnected"
			case .connecting:
				self.toggle.isEnabled = false
				self.toggle.isOn = true

				self.spinner.startAnimating()
				self.statusLabel.text = "Connecting..."
			case .connected:
				self.toggle.isEnabled = true
				self.toggle.isOn = true

				self.spinner.stopAnimating()
				self.statusLabel.text = "Connected"
			case .reasserting:
				self.toggle.isEnabled = false

				self.spinner.startAnimating()
				self.statusLabel.text = "Reasserting..."
			case .disconnecting:
				self.toggle.isEnabled = false

				self.spinner.startAnimating()
				self.statusLabel.text = "Disconnecting..."
			@unknown default:
				self.toggle.isEnabled = true
				self.toggle.isOn = false

				self.spinner.stopAnimating()
				self.statusLabel.text = "Unknown"
			}
		})
	}
	
}
