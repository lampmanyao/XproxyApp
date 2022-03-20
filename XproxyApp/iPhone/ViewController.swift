//
//  ViewController.swift
//  Xproxy
//
//  Created by lampman on 2022/3/8.
//

import UIKit
import NetworkExtension

class ViewController: UITableViewController {

	var managers = [NEVPNManager]()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.title = "Xproxy"
		navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "info.circle"),
														   style: .plain, target: self, action: #selector(showAbout))
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addVPN))
		
        tableView.register(UINib(nibName: "VpnInfoTableViewCell", bundle: nil), forCellReuseIdentifier: "VpnInfoTableViewCell")
		
		reloadManagers()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		reloadManagers()
	}
	
	@objc private func addVPN() {
		let vc = VpnConfViewController.instance()
		navigationController?.pushViewController(vc, animated: true)
	}
	
	func reloadManagers() {
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in
            guard let vpnManagers = newManagers else { return }
            self.managers = vpnManagers
			self.tableView.reloadData()
        }
    }
	
	func deleteManager(at: Int) {
		managers[at].removeFromPreferences() { error in
			if error != nil {
				NSLog("\(error!.localizedDescription)")
			}
		}
		managers.remove(at: at)
	}
	
	@objc private func showAbout() {
		let vc = AboutTableViewController.instance()
		navigationController?.pushViewController(vc, animated: true)
	}

	private func presentError(_ error: Error) {
		let alertController = UIAlertController(title: String(describing: type(of: error)),
												message: error.localizedDescription, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { _ in
			alertController.dismiss(animated: true)
		})
		present(alertController, animated: true)
	}

	@objc func toggle(_ sender: UISwitch) {
		let vpnManager = managers[sender.tag]
        if sender.isOn {
			vpnManager.isEnabled = true
            vpnManager.saveToPreferences { (error) in
                if let error = error {
                    self.presentError(error)
                    return
                }

                self.startVPNTunnel(vpnManager)
            }
        } else {
            vpnManager.connection.stopVPNTunnel()
        }
    }
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return managers.count
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let storyboard = UIStoryboard(name: "iPhone", bundle: nil)
		let vc = storyboard.instantiateViewController(withIdentifier: "VpnConfViewController") as! VpnConfViewController
		vc.vpnManager = managers[indexPath.row]
		navigationController?.pushViewController(vc, animated: true)
	}
	
	private func startVPNTunnel(_ vpnManager: NEVPNManager) {
		do {
			try vpnManager.connection.startVPNTunnel()
		} catch {
			presentError(error)
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VpnInfoTableViewCell", for: indexPath) as! VpnInfoTableViewCell
		cell.tag = indexPath.row
		cell.toggle.tag = indexPath.row
		cell.toggle.addTarget(self, action: #selector(toggle), for: .valueChanged)
		let manager = managers[indexPath.row]
		cell.manager = manager
		cell.observeVpnStatus()
		if manager.connection.status == .connected {
			cell.toggle.isOn = true
		} else {
			cell.toggle.isOn = false
		}
		
		if let providerConfiguration = (manager.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration {
			cell.nameLabel.text = providerConfiguration["name"] as? String
			cell.addressLabel.text = providerConfiguration["address"] as? String
		}
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 100.0
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			deleteManager(at: indexPath.row)
			tableView.deleteRows(at: [indexPath], with: .fade)
		} else if editingStyle == .insert {
			
		}
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
}

