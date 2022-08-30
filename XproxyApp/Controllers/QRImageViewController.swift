//
//  QRImageViewController.swift
//  Xproxy
//
//  Created by lampman on 2022/8/30.
//

import UIKit

class QRImageViewController: UIViewController {
    
    @IBOutlet weak var qrImageView: UIImageView!
    
    var qrImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        qrImageView.image = qrImage
        navigationItem.title = "QR Code"
        let barItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveToPhoto))
        navigationItem.rightBarButtonItem = barItem
    }
    
    class func instance() -> Self {
        let storyboard = UIStoryboard(name: "QRImageViewController", bundle: nil)
        return storyboard.instantiateInitialViewController() as! Self
    }
    
    @objc private func saveToPhoto() {
        UIImageWriteToSavedPhotosAlbum(qrImage!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            self.presentAlert("Save Error", error.localizedDescription)
        } else {
            self.presentAlert("Saved!", "QR Code image has been saved to photos.")
        }
    }
    
}
