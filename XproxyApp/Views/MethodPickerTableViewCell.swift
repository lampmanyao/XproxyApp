//
//  MethodPickerTableViewCell.swift
//  Xproxy
//
//  Created by lampman on 2022/3/16.
//

import UIKit

protocol MethodPickerTableViewCellDelegate {
	func didSelect(_ cell: MethodPickerTableViewCell, didPick row: Int, value: Any)
}

class MethodPickerTableViewCell: UITableViewCell {
	
	@IBOutlet weak var textField: UITextField!
	
	public var delegate: MethodPickerTableViewCellDelegate?

	let picker = UIPickerView()
	
	var dataSource : [String] = []
	
	public var selectedRow: Int {
		get {
			return _selectedRow
		}
		
		set {
			setSelectedRow(newValue, animated: true)
		}
	}
	private var _selectedRow: Int = 0
	
	public func setSelectedRow(_ row: Int, animated: Bool) {
		_selectedRow = row
		picker.selectRow(row, inComponent: 0, animated: animated)
		textField.text = dataSource[row]
	}
	
    override func awakeFromNib() {
        super.awakeFromNib()
		textField.inputView = picker
		picker.dataSource = self
		picker.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

extension MethodPickerTableViewCell: UIPickerViewDelegate {
	public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return dataSource[row]
	}
  
	public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		textField.text = dataSource[row]
		delegate?.didSelect(self, didPick: row, value: dataSource[row])
  }
}

extension MethodPickerTableViewCell: UIPickerViewDataSource {
	public func numberOfComponents(in pickerView: UIPickerView) -> Int {
		return 1
	}
  
	public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return dataSource.count
	}
}
