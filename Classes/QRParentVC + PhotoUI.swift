//
//  QRParentVC + PhotoUI.swift
//  Americana
//
//  Created by Utkarsh on 12/10/20.
//  Copyright © 2020 ambrish. All rights reserved.

import UIKit
import PhotosUI

@available(iOS 14, *)
class PhotoUIPicketManager: NSObject, PHPickerViewControllerDelegate  {

    var vc = UIViewController()
    var openPhoneSettings : (() -> Void)?
    var pickedImage : ((UIImage) -> Void)?

    override init() {
        super.init()
    }
    
    func instantiatePicker(viewController: UIViewController){
        self.vc = viewController
        self.checkPHPickerAuthorization()
    }
    
    private func presentPicker() {
        
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = .any(of: [.images])
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        vc.present(picker, animated: true)
    }
    
    
    private func checkPHPickerAuthorization(){
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined:
            self.requestAuthorization()
        case .restricted, .denied:
            self.openPhoneSettings?()
        case .authorized, .limited:
            self.presentPicker()
        @unknown default:
            self.presentPicker()
        }
    }

    private func requestAuthorization(){
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            //
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        vc.dismiss(animated: true)
        let itemProviders = results.map(\.itemProvider)
        for item in itemProviders {
            if item.canLoadObject(ofClass: UIImage.self) {
                item.loadObject(ofClass: UIImage.self) { (image, error) in
                    DispatchQueue.main.async {
                        if let pickedImage = image as? UIImage {
                            self.pickedImage?(pickedImage)
                        }
                    }
                }
            }
        }
    }
}


