//
//  ScannerViewController.swift
//  Xproxy
//
//  Created by lampman on 2022/8/30.
//

import AVFoundation
import UIKit

class ScannerViewController: UIViewController {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var delegate: VpnConfigurationDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    class func instance() -> Self {
        let storyboard = UIStoryboard(name: "ScannerViewController", bundle: nil)
        return storyboard.instantiateInitialViewController() as! Self
    }
    
    private func setup() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        captureSession.startRunning()
    }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            let array = stringValue.split(separator: "\r\n")
            var dict: [String:String] = [:]
            for item in array {
                let arr = item.split(separator: ":")
                if arr.count == 2 {
                    dict[String(arr[0])] = String(arr[1])
                }
            }
            var vpnConfiguration = VpnConfiguration()
            vpnConfiguration.name = dict["name"]
            vpnConfiguration.address = dict["address"]
            vpnConfiguration.port = dict["port"]
            vpnConfiguration.password = dict["password"]
            vpnConfiguration.method = dict["method"]
            self.delegate?.applyVpnConfig(vpnConfiguration: vpnConfiguration)
        }
        self.navigationController?.popViewController(animated: true)
    }
}
