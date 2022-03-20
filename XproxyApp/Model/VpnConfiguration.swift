//
//  VpnConfiguration.swift
//  Xproxy
//
//  Created by lampman on 2022/3/18.
//

import Foundation

struct VpnConfiguration {
	var name: String?
	var address: String?
	var port: String?
	var password: String?
	var method: String?
	var exceptionList: [String] = []
	
	func providerConfiguration() -> [String : Any]? {
		if name == nil || address == nil || port == nil || password == nil || method == nil {
			return  nil
		}
		
		var conf: [String : Any] = [:]
		conf["name"] = name
		conf["address"] = address
		conf["port"] = port
		conf["password"] = password
		conf["method"] = method
		conf["exceptionList"] = exceptionList.filter { $0 != "" }
		return conf
	}
}
