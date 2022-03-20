//
//  VpnDescriptionTableViewCell.swift
//  Xproxy
//
//  Created by lampman on 2022/3/12.
//

import UIKit

class PadVpnInfoTableViewCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        nameLabel.text =  "New VPN"
        addressLabel.text = nil
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
