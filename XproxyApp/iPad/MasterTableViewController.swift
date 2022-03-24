//
//  RootTableViewController.swift
//  Xproxy
//
//  Created by lampman on 2022/3/11.
//

import UIKit
import NetworkExtension

protocol MasterTableViewControllerDelegate {
    func reloadManagers()
}

class MasterTableViewController: UITableViewController, MasterTableViewControllerDelegate {

    var managers = [NEVPNManager]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "info.circle"),
                                                           style: .plain, target: self, action: #selector(showAbout))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self, action: #selector(addVPN))
        
        navigationItem.title = "Xproxy"
        tableView.register(UINib(nibName: "PadVpnInfoTableViewCell", bundle: nil), forCellReuseIdentifier: "PadVpnInfoTableViewCell")
        
        self.view.backgroundColor = UIColor(named: "XproxyBackgroudColor")
        self.tableView.backgroundColor = UIColor(named: "XproxyBackgroundColor")
        
        reloadManagers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadManagers()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if UIDevice.current.orientation.isLandscape {
            splitViewController?.preferredDisplayMode = .twoBesideSecondary
        } else {
            splitViewController?.preferredDisplayMode = .twoBesideSecondary
        }
    }
    
    class func instance() -> MasterTableViewController {
        let storyboard = UIStoryboard(name: "iPad", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "MasterTableViewController") as! MasterTableViewController
    }
    
    func reloadManagers() {
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in
            guard let vpnManagers = newManagers else { return }
            self.managers = vpnManagers
            if vpnManagers.isEmpty {
                self.managers.append(NETunnelProviderManager())
            }
            var indexPath: IndexPath = IndexPath(row: 0, section: 0)
            for (row, mgr) in self.managers.enumerated() {
                if mgr.connection.status == .connected {
                    indexPath = IndexPath(row: row, section: 0)
                    break
                }
            }
            let vc = PadVpnConfViewController.instance()
            vc.delegate = self
            vc.vpnManager = self.managers[indexPath.row]
            self.tableView.reloadData()
            self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            self.splitViewController?.setViewController(vc, for: .secondary)
        }
    }
    
    @objc private func showAbout() {
        let storyboard = UIStoryboard(name: "iPhone", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "AboutTableViewController") as! AboutTableViewController
        splitViewController?.setViewController(vc, for: .secondary)
    }

    @objc private func addVPN() {
        let manager = NETunnelProviderManager()
        managers.append(manager)
        tableView.reloadData()
        let vc = PadVpnConfViewController.instance()
        vc.vpnManager = manager
        vc.delegate = self
        let indexPath = IndexPath(row: managers.count - 1, section: 0)
        self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        splitViewController?.setViewController(vc, for: .secondary)
    }
    
    private func deleteManager(at: Int) {
        managers[at].removeFromPreferences() { error in
            if error != nil {
                NSLog("\(error!.localizedDescription)")
            }
        }
        managers.remove(at: at)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return managers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PadVpnInfoTableViewCell", for: indexPath) as! PadVpnInfoTableViewCell
        let vpnManager = managers[indexPath.row]
        guard let conf = (vpnManager.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration else { return cell }
        cell.nameLabel.text = conf["name"] as? String
        cell.addressLabel.text = conf["address"] as? String
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = PadVpnConfViewController.instance()
        vc.vpnManager = managers[indexPath.row]
        splitViewController?.hide(.secondary)
        splitViewController?.setViewController(vc, for: .secondary)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 58
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteManager(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            reloadManagers()
        }
    }

}
