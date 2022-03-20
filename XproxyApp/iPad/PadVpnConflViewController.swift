//
//  PadVpnConfViewController.swift
//  Xproxy
//
//  Created by lampman on 2022/3/12.
//

import UIKit
import NetworkExtension

class PadVpnConfViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var addExceptionButton: UIButton!
    var delExceptionButton: UIButton!
    
    var delegate: MasterTableViewControllerDelegate?
    
    var vpnManager: NEVPNManager?
    
    var vpnConfiguration = VpnConfiguration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveVpn))
        navigationItem.title = "New VPN"
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "VpnTableViewCell", bundle: nil), forCellReuseIdentifier: "VpnTableViewCell")
        tableView.register(UINib(nibName: "VpnStatusTableViewCell", bundle: nil), forCellReuseIdentifier: "VpnStatusTableViewCell")
        tableView.register(UINib(nibName: "ExceptionTableViewCell", bundle: nil), forCellReuseIdentifier: "ExceptionCell")
        tableView.register(UINib(nibName: "MethodPickerTableViewCell", bundle: nil), forCellReuseIdentifier: "PickerCell")
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
        
        addExceptionButton = UIButton(frame: CGRect(x: view.frame.width - 40 - 40, y: 0.0, width: 40.0, height: 40.0))
        addExceptionButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        addExceptionButton.addTarget(self, action: #selector(addExceptionButtonCallback), for: .touchUpInside)

        delExceptionButton = UIButton(frame: CGRect(x: view.frame.width - 40 - 80, y: 0.0, width: 40.0, height: 40.0))
        delExceptionButton.setImage(UIImage(systemName: "minus.circle"), for: .normal)
        delExceptionButton.addTarget(self, action: #selector(delExceptionButtonCallback), for: .touchUpInside)
        
        view.backgroundColor = UIColor(named: "XproxyBackgroudColor")
        tableView.backgroundColor = UIColor(named: "XproxyBackgroundColor")
        
        observeRemoteConnectFailure()
    }
    
    private func observeRemoteConnectFailure() {
        let notificationName = String(cString: remote_proxy_connect_failure_name()) as CFString
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())

        CFNotificationCenterAddObserver(notificationCenter,
                                        observer,
                                        { (_, observer, _, _, _) -> Void in
                                            if let observer = observer {
                                                let myself = Unmanaged<PadVpnConfViewController>.fromOpaque(observer).takeUnretainedValue()
                                                myself.showError("Cannot connect to remote-proxy")
                                            }
                                        },
                                        notificationName,
                                        nil,
                                        .coalesce)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let vpnManager = vpnManager {
            guard let conf = (vpnManager.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration else { return }
            vpnConfiguration.name = conf["name"] as? String
            vpnConfiguration.address = conf["address"] as? String
            vpnConfiguration.port = conf["port"] as? String
            vpnConfiguration.password = conf["password"] as? String
            vpnConfiguration.method = conf["method"] as? String
            vpnConfiguration.exceptionList = conf["exceptionList"] as! [String]
            if vpnConfiguration.exceptionList.isEmpty {
                delExceptionButton.isEnabled = false
            }
            navigationItem.title = vpnConfiguration.name
        }
    }
    
    class func instance() -> PadVpnConfViewController {
        let storyboard = UIStoryboard(name: "iPad", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: "PadVpnConfViewController") as! PadVpnConfViewController
    }
    
    private func showError(_ message: String) {
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alertVC, animated: true, completion: nil)
    }
    
    @objc func saveVpn() {
        guard let providerConfiguration = vpnConfiguration.providerConfiguration() else {
            showError("pleass enter the empty filed")
            return
        }
        
        if vpnConfiguration.exceptionList.last == "" {
            vpnConfiguration.exceptionList.removeLast(1)
        }
        
        vpnManager!.isEnabled = true
        vpnManager!.localizedDescription = "Xproxy"

        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerConfiguration = providerConfiguration
        providerProtocol.serverAddress = vpnConfiguration.address
        vpnManager!.protocolConfiguration = providerProtocol
        
        vpnManager!.saveToPreferences { error in
            if let saveError = error {
                self.showError(saveError.localizedDescription)
                return
            }
            self.delegate?.reloadManagers()
        }
    }
    
    @objc func toggle(_ sender: UISwitch) {
        if sender.isOn {
            vpnManager?.isEnabled = true
            self.vpnManager?.saveToPreferences { (error) in
                if let error = error {
                    self.presentError(error)
                    return
                }

                self.startVPNTunnel()
            }
        } else {
            vpnManager?.connection.stopVPNTunnel()
        }
    }
    
    private func startVPNTunnel() {
        do {
            try self.vpnManager?.connection.startVPNTunnel()
        } catch {
            presentError(error)
        }
    }
    
    private func presentError(_ error: Error) {
        let alertController = UIAlertController(title: String(describing: type(of: error)),
                                                message: error.localizedDescription, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { _ in
            alertController.dismiss(animated: true)
        })
        present(alertController, animated: true)
    }
    
    @objc func addExceptionButtonCallback() {
        vpnConfiguration.exceptionList.append("")
        if vpnConfiguration.exceptionList.count > 0 {
            delExceptionButton.isEnabled = true
        }
        tableView.beginUpdates()
        tableView.insertRows(at: [IndexPath(row: vpnConfiguration.exceptionList.count - 1, section: 1)], with: .automatic)
        tableView.endUpdates()
    }

    @objc func delExceptionButtonCallback() {
        if vpnConfiguration.exceptionList.count == 0 {
            delExceptionButton.isEnabled = false
        } else {
            tableView.beginUpdates()
            tableView.deleteRows(at: [IndexPath(row: vpnConfiguration.exceptionList.count - 1, section: 1)], with: .automatic)
            vpnConfiguration.exceptionList.remove(at: vpnConfiguration.exceptionList.count - 1)
            tableView.endUpdates()
            if vpnConfiguration.exceptionList.count == 0 {
                delExceptionButton.isEnabled = false
            }
        }
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        tableView.contentInset = .zero
    }
}

// MARK: - Table view data source

extension PadVpnConfViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            if vpnManager == nil {
                return 5
            } else {
                return 6
            }
        } else {
            return vpnConfiguration.exceptionList.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if vpnManager == nil {
                if indexPath.row < 4 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "VpnTableViewCell", for: indexPath) as! VpnTableViewCell
                    if indexPath.row == 0 {
                        cell.nameLabel.text = "Name"
                        cell.textField.placeholder = "Name"
                    } else if indexPath.row == 1 {
                        cell.nameLabel.text = "Server"
                        cell.textField.placeholder = "Server"
                    } else if indexPath.row == 2 {
                        cell.nameLabel.text = "Port"
                        cell.textField.placeholder = "Port"
                    } else if indexPath.row == 3 {
                        cell.nameLabel.text = "Password"
                        cell.textField.placeholder = "Password"
                    }
                    cell.textField.tag = indexPath.row + 1
                    cell.textField.delegate = self
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "PickerCell", for: indexPath) as! MethodPickerTableViewCell
                    cell.dataSource = SupportMethods
                    cell.delegate = self
                    return cell
                }
            } else {
                if indexPath.row == 0 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "VpnStatusTableViewCell", for: indexPath) as! VpnStatusTableViewCell
                    cell.toggle.addTarget(self, action: #selector(toggle(_:)), for: .valueChanged)
                    cell.manager = vpnManager
                    cell.toggle.isOn = vpnManager!.connection.status == .connected
                    cell.observeVpnStatus()
                    return cell
                } else if indexPath.row < 5 {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "VpnTableViewCell",
                                                             for: indexPath) as! VpnTableViewCell
                
                    if indexPath.row == 1  {
                        cell.nameLabel.text = "Name"
                        cell.textField.text = vpnConfiguration.name
                    } else if indexPath.row == 2 {
                        cell.nameLabel.text = "Server"
                        cell.textField.text = vpnConfiguration.address
                    } else if indexPath.row == 3 {
                        cell.nameLabel.text = "Port"
                        cell.textField.text = vpnConfiguration.port
                    } else if indexPath.row == 4 {
                        cell.nameLabel.text = "Password"
                        cell.textField.text = vpnConfiguration.password
                    }
                    cell.textField.tag = indexPath.row
                    cell.textField.delegate = self
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "PickerCell", for: indexPath) as! MethodPickerTableViewCell
                    cell.dataSource = SupportMethods
                    cell.textField.text = vpnConfiguration.method
                    cell.delegate = self
                    return cell
                }
            }
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ExceptionCell", for: indexPath) as! ExceptionTableViewCell
            cell.textField.delegate = self
            cell.textField.text = vpnConfiguration.exceptionList[indexPath.row]
            cell.tag = 20
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40.0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 40.0))
            let label = UILabel(frame: CGRect(x: 20, y: 0, width: 120, height: 40))
            label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            label.text = "XPROXY"
            label.textColor = .gray
            headerView.addSubview(label)
            return headerView
        } else {
            let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 40.0))
            let label = UILabel(frame: CGRect(x: 20, y: 0, width: 200, height: 40))
            label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            label.text = "EXCEPTION DOMAIN"
            label.textColor = .gray
            headerView.addSubview(label)
            headerView.addSubview(addExceptionButton)
            headerView.addSubview(delExceptionButton)

            addExceptionButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                addExceptionButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                addExceptionButton.widthAnchor.constraint(equalToConstant: 40.0),
                addExceptionButton.heightAnchor.constraint(equalToConstant: 40.0),
                addExceptionButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor)
            ])

            delExceptionButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                delExceptionButton.widthAnchor.constraint(equalToConstant: 40.0),
                delExceptionButton.heightAnchor.constraint(equalToConstant: 40.0),
                delExceptionButton.trailingAnchor.constraint(equalTo: addExceptionButton.leadingAnchor)
            ])
            return headerView
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 1 {
            if vpnConfiguration.exceptionList.count > 0 {
                let footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 40.0))
                let label = UILabel(frame: CGRect(x: 20, y: 0, width: view.frame.width, height: 40))
                label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
                label.text = "NOTE: THOSE DOMAINS WILL NOT PASS TO VPN"
                label.textColor = .gray
                footerView.addSubview(label)
                return footerView
            }
        }
        return nil
    }
}

extension PadVpnConfViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        let tag = textField.tag
        if tag == 1 {
            vpnConfiguration.name = textField.text
        } else if tag == 2 {
            vpnConfiguration.address = textField.text
        } else if tag == 3 {
            vpnConfiguration.port = textField.text
        } else if tag == 4 {
            vpnConfiguration.password = textField.text
        } else if tag == 5 {
            vpnConfiguration.method = textField.text
        } else {
            if textField.text != nil {
                if vpnConfiguration.exceptionList.last == "" {
                    vpnConfiguration.exceptionList.removeLast(1)
                }
                vpnConfiguration.exceptionList.append(textField.text!)
            }
        }
        return true
    }
}

extension PadVpnConfViewController: MethodPickerTableViewCellDelegate {
    func didSelect(_ cell: MethodPickerTableViewCell, didPick row: Int, value: Any) {
        vpnConfiguration.method = cell.textField.text
        self.view.endEditing(true)
    }
}
