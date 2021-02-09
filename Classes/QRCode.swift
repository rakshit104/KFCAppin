//

import UIKit
import AVFoundation

open class QRCode: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    
    let handleUrl = HandleQRCodeLink.shared
    /// corner line width
    var lineWidth: CGFloat
    /// corner stroke color
    var strokeColor: UIColor
    /// the max count for detection
    var maxDetectedCount: Int
    /// current count for detection
    var currentDetectedCount: Int = 0
    /// auto remove sub layers when detection completed
    var autoRemoveSubLayers: Bool
    /// completion call back
    var completedCallBack: ((_ stringValue: String) -> ())?
    /// the scan rect, default is the bounds of the scan view, can modify it if need
    
    var completedCallBackHandleURL: ((_ storyId: String,_ countryID: String,_ type: String,_ coupon: String,_ extraDetail: String) -> Void)?
    
    var scannerPermissionsCallback: ((Bool) -> Void)?
    var getValuesFromUrl: (([String:String]) -> Void)?
    var sendRedirectedUrl: ((String) -> Void)?
    var errorReadingQR: (() -> Void)?
    
    var openPhoneSettings : (() -> Void)?
    var pickedImage : ((UIImage) -> Void)?
    
    open var scanFrame: CGRect = CGRect.zero
    
    ///  init function
    ///
    ///  - returns: the scanner object
    public override init() {
        self.lineWidth = 4
        self.strokeColor = UIColor.clear
        self.maxDetectedCount = 20
        self.autoRemoveSubLayers = false
        
        super.init()
    }
    
    ///  init function
    ///
    ///  - parameter autoRemoveSubLayers: remove sub layers auto after detected code image
    ///  - parameter lineWidth:           line width, default is 4
    ///  - parameter strokeColor:         stroke color, default is Green
    ///  - parameter maxDetectedCount:    max detecte count, default is 20
    ///
    ///  - returns: the scanner object
    public init(autoRemoveSubLayers: Bool, lineWidth: CGFloat = 4, strokeColor: UIColor = UIColor.green, maxDetectedCount: Int = 20) {
        
        self.lineWidth = lineWidth
        self.strokeColor = strokeColor
        self.maxDetectedCount = maxDetectedCount
        self.autoRemoveSubLayers = autoRemoveSubLayers
    }
    
    deinit {
        if session.isRunning {
            session.stopRunning()
        }
        
        removeAllLayers()
    }
    
    // MARK: - Generate QRCode Image
    ///  generate image
    ///
    ///  - parameter stringValue: string value to encoe
    ///  - parameter avatarImage: avatar image will display in the center of qrcode image
    ///  - parameter avatarScale: the scale for avatar image, default is 0.25
    ///
    ///  - returns: the generated image
    class open func generateImage(_ stringValue: String, avatarImage: UIImage?, avatarScale: CGFloat = 0.25) -> UIImage? {
        return generateImage(stringValue, avatarImage: avatarImage, avatarScale: avatarScale, color: CIColor(color: UIColor.black), backColor: CIColor(color: UIColor.white))
    }
    
    ///  Generate Qrcode Image
    ///
    ///  - parameter stringValue: string value to encoe
    ///  - parameter avatarImage: avatar image will display in the center of qrcode image
    ///  - parameter avatarScale: the scale for avatar image, default is 0.25
    ///  - parameter color:       the CI color for forenground, default is black
    ///  - parameter backColor:   th CI color for background, default is white
    ///
    ///  - returns: the generated image
    class open func generateImage(_ stringValue: String, avatarImage: UIImage?, avatarScale: CGFloat = 0.25, color: CIColor, backColor: CIColor) -> UIImage? {
        
        // generate qrcode image
        let qrFilter = CIFilter(name: "CIQRCodeGenerator")!
        qrFilter.setDefaults()
        qrFilter.setValue(stringValue.data(using: String.Encoding.utf8, allowLossyConversion: false), forKey: "inputMessage")
        
        let ciImage = qrFilter.outputImage
        
        // scale qrcode image
        let colorFilter = CIFilter(name: "CIFalseColor")!
        colorFilter.setDefaults()
        colorFilter.setValue(ciImage, forKey: "inputImage")
        colorFilter.setValue(color, forKey: "inputColor0")
        colorFilter.setValue(backColor, forKey: "inputColor1")
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let transformedImage = qrFilter.outputImage!.transformed(by: transform)
        
        let image = UIImage(ciImage: transformedImage)
        
        if avatarImage != nil {
            return insertAvatarImage(image, avatarImage: avatarImage!, scale: avatarScale)
        }
        
        return image
    }
    
    class func insertAvatarImage(_ codeImage: UIImage, avatarImage: UIImage, scale: CGFloat) -> UIImage {
        
        let rect = CGRect(x: 0, y: 0, width: codeImage.size.width, height: codeImage.size.height)
        UIGraphicsBeginImageContext(rect.size)
        
        codeImage.draw(in: rect)
        
        let avatarSize = CGSize(width: rect.size.width * scale, height: rect.size.height * scale)
        let x = (rect.width - avatarSize.width) * 0.5
        let y = (rect.height - avatarSize.height) * 0.5
        avatarImage.draw(in: CGRect(x: x, y: y, width: avatarSize.width, height: avatarSize.height))
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return result!
    }
    
    // MARK: - Video Scan
    ///  prepare scan
    ///
    ///  - parameter view:       the scan view, the preview layer and the drawing layer will be insert into this view
    ///  - parameter completion: the completion call back
    open func prepareScan(_ view: UIView, completion:@escaping (_ stringValue: String)->()) {

        scanFrame = view.bounds

        completedCallBack = completion
        currentDetectedCount = 0

        setupSession()
        setupLayers(view)
    }
    
    /// start scan
    open func startScan() {
        if session.isRunning {
            print("the  capture session is running")
            
            return
        }
        session.startRunning()
    }
    
    /// stop scan
    open func stopScanning() {
        if !session.isRunning {
            print("the capture session is not running")
            return
        }
        print("the capture session is stop running")
        self.session.stopRunning()
    }
    
    func setupLayers(_ view: UIView) {
        drawLayer.frame = view.bounds
        view.layer.insertSublayer(drawLayer, at: 0)
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
    }
    
    ///  setupSession function
    ///  This function manages the current scanning session based upon the authorization status.
    func setupSession() {
        if session.isRunning {
            print("the capture session is running")
            return
        }
        
        guard let input = videoInput else{ return }
        
        if AVCaptureDevice.authorizationStatus(for: .video) ==  .authorized {
            //already authorized
            
            session.addInput(input)
            session.addOutput(dataOutput)
            
            dataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]//dataOutput.availableMetadataObjectTypes;
            dataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                self.scannerPermissionsCallback?(granted)
                if granted {
                    self.session.addInput(input)
                    self.session.addOutput(self.dataOutput)
                    
                    self.dataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]//dataOutput.availableMetadataObjectTypes;
                    self.dataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                } else {
                    //access denied
                }
            })
        }
    }
    
    
    public  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection)
    {
        
        clearDrawLayer()
        
        for dataObject in metadataObjects {
            
            if let codeObject = dataObject as? AVMetadataMachineReadableCodeObject,
               let obj = previewLayer.transformedMetadataObject(for: codeObject) as? AVMetadataMachineReadableCodeObject {
                
                if scanFrame.contains(obj.bounds) {
                    currentDetectedCount = currentDetectedCount + 1
                    if currentDetectedCount > maxDetectedCount {
                        //                        if codeObject.stringValue!.contains("uae.kfc.me") {
                        session.stopRunning()
                        
                        self.handleURL(url: codeObject.stringValue!)
                        completedCallBack!(codeObject.stringValue!)
                        //                      }
                        if autoRemoveSubLayers {
                            removeAllLayers()
                        }
                    }
                    
                }
            }
        }
    }
    
    open func removeAllLayers() {
        previewLayer.removeFromSuperlayer()
        drawLayer.removeFromSuperlayer()
    }
    
    func clearDrawLayer() {
        if drawLayer.sublayers == nil {
            return
        }
        
        for layer in drawLayer.sublayers! {
            layer.removeFromSuperlayer()
        }
    }
    
    func createPath(_ points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        
        var point =  points[0] ;// CGPoint(x: points[0], y: <#T##CGFloat#>)//(dictionaryRepresentation: points[0] as! CFDictionary)
        path.move(to: point)
        
        var index = 1
        while index < points.count {
            point = points[index]//CGPoint(dictionaryRepresentation: points[index] as! CFDictionary)
            path.addLine(to: point)
            
            index = index + 1
        }
        path.close()
        
        return path
    }
    
    /// previewLayer
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.session)
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        return layer
    }()
    
    /// drawLayer
    lazy var drawLayer = CALayer()
    /// session
    lazy var session = AVCaptureSession()
    /// input
    lazy var videoInput: AVCaptureDeviceInput? = {
        
        if let device = AVCaptureDevice.default(for: .video){//defaultDevice(withMediaType: AVMediaTypeVideo) {
            return try? AVCaptureDeviceInput(device: device)
        }
        return nil
    }()
    
    /// output
    lazy var dataOutput = AVCaptureMetadataOutput()
    
    
    ///  Pick the QR Code Image from Gallery function
    ///
    ///  - parameter vc: The calling ViewController
    ///  - parameter isGallaryPermissionEnabled: Bool if user has allowed the Gallery Access Permissions.
    ///  - parameter completion: the completion callback - providing extracted values from QR
    ///  - parameter failure: the failure callback - returns the error
    
    internal func pickQRCodeImageFromGallary(_ vc: UIViewController, isGallaryPermissionEnabled:Bool, completion: @escaping (_ storyId: String,_ countryID: String,_ type: String,_ coupon: String,_ extraDetail: String) -> Void, failure: @escaping ((Error) -> Void)){
        if !isGallaryPermissionEnabled{
            return
        }
        
        if #available(iOS 14, *) {
            let picker = PhotoUIPicketManager()
            picker.instantiatePicker(viewController: vc)
            picker.openPhoneSettings = {[weak self] in
                self?.openPhoneSettings?()
            }
            picker.pickedImage = {[weak self] (pickedImage) in
                self?.handlePickedImageFromGallery(pickedImage: pickedImage)
            }
        } else {
            // Fallback on earlier versions
            ImagePickerManager().pickImage(vc) { (pickedImage) in
                self.handlePickedImageFromGallery(pickedImage: pickedImage)
            }
        }
        
    }
    
    ///  Scan QR from camera
    ///
    ///  - parameter view: The calling view
    ///  - parameter isCameraPermissionEnabled: Bool if user has allowed the Camera Access Permissions.
    ///  - parameter completion: the completion callback - providing extracted values from QR
    ///  - parameter failure: the failure callback - returns the error
    internal func startScanning(_ view: UIView, isCameraPermissionEnabled:Bool, completion: @escaping (_ storyId: String,_ countryID: String,_ type: String,_ coupon: String,_ extraDetail: String) -> Void, failure: @escaping ((Error) -> Void)){
        if !isCameraPermissionEnabled{
            return
        }
        
        scanFrame = view.bounds
        
        completedCallBackHandleURL = completion
        currentDetectedCount = 0
        
        setupSession()
        setupLayers(view)
    }
    
    
    ///  Use the provided url to fetch values
    ///
    ///  - parameter url: the url extracted from the scanner QR
    private func handleURL(url: String){
        
        self.handleUrl.sendRedirectedUrl = {[weak self] redirectUrl in
            guard let wSelf = self else { return }
            // this closure returns to us the redirected url from the parent url
            wSelf.sendRedirectedUrl?(redirectUrl)
        }
        
        self.handleUrl.errorReadingQR = {[weak self] in
            // this closure handles the errors encountered during the url parsing
            guard let wSelf = self else { return }
            wSelf.errorReadingQR?()
        }
        
        self.handleUrl.getValuesFromUrl = {[weak self](values) in
            guard let wSelf = self else { return }
            wSelf.getValuesFromUrl?(values)
            wSelf.completedCallBackHandleURL?(values["storeid"] ?? "", values["countryid"] ?? "", values["type"] ?? "", values["autoapplycoupon"] ?? "", values["extradetails"] ?? "")
        }
        
        handleUrl.getRedirectUrl(urlString: url)
    }
    
    ///  Extract the URL from the Picked Image
    ///
    ///  - parameter pickedImage: the image picked for scanning the QR
    private func handlePickedImageFromGallery(pickedImage: UIImage){
        // this is called when an image is picked from the photo library
        let arrStr = pickedImage.parseQR()
        if arrStr.count != 1{
            // If the fetched image does not contains a valid/readable QR
            self.errorReadingQR?()
            return
        }
        
        if let stringValue = arrStr.first{
            self.handleURL(url: stringValue)
        }
    }
}

extension UIImage {
    func parseQR() -> [String] {
        guard let image = CIImage(image: self) else {
            return []
        }

        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: nil,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])

        let features = detector?.features(in: image) ?? []

        return features.compactMap { feature in
            return (feature as? CIQRCodeFeature)?.messageString
        }
    }
}
