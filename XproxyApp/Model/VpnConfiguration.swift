//
//  VpnConfiguration.swift
//  Xproxy
//
//  Created by lampman on 2022/3/18.
//

import Foundation
import UIKit

protocol VpnConfigurationDelegate {
    func applyVpnConfig(vpnConfiguration: VpnConfiguration?)
}

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
    
    private func convert(_ cmage: CIImage) -> UIImage? {
        let context:CIContext = CIContext(options: nil)
        guard let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent) else { return nil }
        let image:UIImage = UIImage(cgImage: cgImage)
        return image
    }
    
    private func generateQRCodeImage(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)

            if let output = filter.outputImage?.transformed(by: transform) {
                return convert(output)
            }
        }
        
        return nil
    }
    
    private func generateQRCodeColorfulImage(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            guard let colorFilter = CIFilter(name: "CIFalseColor") else { return nil }
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel")
            colorFilter.setValue(filter.outputImage, forKey: "inputImage")
            colorFilter.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor1")
            colorFilter.setValue(CIColor(cgColor: UIColor.systemBlue.cgColor), forKey: "inputColor0")
            let transform = CGAffineTransform(scaleX: 5, y: 5)
            if let output = colorFilter.outputImage?.transformed(by: transform) {
                return convert(output)
            }
        }
        return nil
    }
    
    func genQRImage() -> UIImage? {
        if name == nil || address == nil || port == nil || password == nil || method == nil {
            return nil
        }
        
        let str = "name:\(name!)\r\naddress:\(address!)\r\nport:\(port!)\r\npassword:\(password!)\r\nmethod:\(method!)"
        return generateQRCodeImage(from: str)
    }
}
