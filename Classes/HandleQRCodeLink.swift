//
//  HandleQRCodeLink.swift
//  QRCodeScannerDemo
//
//  Created by Utkarsh on 21/09/20.
//  Copyright © 2020 ambrish. All rights reserved.
//

import Foundation
//import Adjust

class HandleQRCodeLink: NSObject, URLSessionTaskDelegate {
    
    /// Shared instance for HandleQRCodeLink
    static let shared = HandleQRCodeLink()
    /// keep the redirect url received upon redirection
    var redirectURL = ""
    /// class attributes
    var attributes = DeeplinkAttributes()
    /// Closure for providing the values from URL
    var getValuesFromUrl: (([String:String]) -> Void)?
    /// Closure for providing the redirect url from parent url
    var sendRedirectedUrl: ((String) -> Void)?
    /// Closure for reporting error with url
    var errorReadingQR: (() -> Void)?
    
    
    // MARK: - Get Values from the URL
    ///  Analyse the URL and perform required actions.
    ///
    ///  - parameter urlString: the parent url for extraction
    internal func getRedirectUrl(urlString : String) {
        // Check if the QR Direct url is itself a valid deeplink url

        if let universalLink = self.getAdjustUniversalLink(url: urlString), !universalLink.isEmpty{
            self.redirectURL = urlString
            self.handleUniversalDeeplink(universalLink: universalLink)
        }else if self.checkRedirectURLForDeeplink(str: urlString){
            var fetchValues = self.fetchValues(url: urlString)
            if let deeplinkUrl = self.prepareUrlFrom(values: fetchValues){
                fetchValues[attributes.keyForDeeplingURL] = deeplinkUrl
                self.redirectURL = deeplinkUrl
                self.getValuesFromUrl?(fetchValues)
            }
        } else{
            self.startSessionWith(urlString: urlString)
        }
    }
        
    ///  Prepare a valid Brand URL from the provided attributes function
    ///
    ///  - parameter values: the attributes and values for preparing a brand url
    private func prepareUrlFrom(values: [String:String]) -> String?{
        var dict = values
        if var host = dict[attributes.keyForPreparingURLFromDict]{
            for item in attributes.removeValuesForKeyInPrepareURL{
                dict.removeValue(forKey: item)
            }
            host = host + "?"
            for value in dict{
                host = host + "\(value.key)=\(value.value)&"
            }
            host.removeLast()
            return host
        }
        return nil
    }
    
    ///  Handle the Universal Deeplink - Brand Specific
    ///
    ///  - parameter universalLink: the universal deeplink
    private func handleUniversalDeeplink(universalLink: String){
        if self.checkRedirectURLForDeeplink(str: universalLink) || universalLink.contains(attributes.validAddressSubtypeOfUrl)
            || !universalLink.isEmpty{
            //universalLink.contains("deep_link") || universalLink.contains("deeplink"){
            self.getValuesFromUrl?(self.fetchValues(url: universalLink))
        }else{
            /** QR is not matched*/
            self.errorReadingQR?()
        }
    }
    
    ///  retrive the values from url function
    ///
    ///  - parameter url: the URL string for fetching the values
    ///  - parameter needsClosure: If required can return the values or error through closure.
    internal func fetchValues(url: String, needsClosure: Bool = false) -> [String: String]{
        // This function fetches the values from the deeplink url in the form of [String: String]
        var finalValues = [String: String]()
        
        if let queryItems = URLComponents(string: url)?.queryItems, let filterUrl = queryItems.filter({$0.name == "url"}).first?.value{
            
            let type = URLComponents(string: filterUrl)?.queryItems?.filter({$0.name == "type"}).first?.value
            
            var dict = [String:String]()
            dict["type"] = "\(type ?? "")"
            for instance in queryItems{
                dict["\(instance.name.lowercased())"] = "\(instance.value ?? "")"
            }
            finalValues = dict
            if needsClosure{
                self.getValuesFromUrl?(dict)
            }
        }else if let queryItems = URLComponents(string: url)?.queryItems{
            var dict = [String:String]()

            if let tempURL = URL(string: url){
                dict["url"] = tempURL.host
            }
            for instance in queryItems{
                dict["\(instance.name.lowercased())"] = "\(instance.value ?? "")"
            }
            finalValues = dict
            if needsClosure{
                self.getValuesFromUrl?(dict)
            }
        }else{
            if needsClosure{
                self.errorReadingQR?()
            }
        }
        return finalValues
    }
    
    ///  Get the Universal Deeplink from Adjust function
    ///
    ///  - parameter url: The Url for getting the Universal Link
    private func getAdjustUniversalLink(url: String) -> String?{
//        let decodedUrl = url.removingPercentEncoding ?? ""
//
//        if let urlString = URL.init(string: url) , let link = Adjust().convertUniversalLink(urlString, scheme: ""){
//            return link.absoluteString
//        }else if let urlString = URL.init(string: decodedUrl), let link = Adjust().convertUniversalLink(urlString, scheme: ""){
//            return link.absoluteString
//        }
//        return nil
        return ""
    }
    
    ///  Validate the URL based on the countryId
    ///
    ///  - parameter url: The URL to ve validated
    ///  - parameter countryId: The countryId received in the url
    ///
    ///  - returns: true if URL is valid else false
    internal func validateURL(url: String = "", countryId: String) -> Bool{
        // returns if the url is a valid deeplink url
        return countryId == attributes.currentCountry
    }
    
    ///  Validate the URL is a valid Adjust URL
    ///
    ///  - parameter url: The URL to ve validated
    ///
    ///  - returns: true if URL is a valid Adjust URL else false
    internal func validateRedirectUrlForAdjust(url: String) -> Bool{
        // checks if the url is a valid Adjust url
        if let redirectUrl = URL(string: url), let host = redirectUrl.host{
            if self.checkURLForValidHostNames(str: host){
                return true
            }
        }
        return false
    }
    
    ///  Validate the URL is a valid Rebrandly URL
    ///
    ///  - parameter url: The URL to ve validated
    ///
    ///  - returns: true if URL is a valid Rebrandly URL else false
    internal func checkRebrandlyUrl(url: String) -> Bool{
        // checks if the url is a Rebrandly url
        if let convertedUrl = URL(string: url), let hostName = convertedUrl.host, hostName == QRAppConstants.rebrandlyURL.rawValue{
            return true
        }
        return false
    }
    
}

extension HandleQRCodeLink{
    // Extended for Redirection Handling
    
    ///  Setup and start an URL Session
    ///
    ///  - parameter urlString: the URL used for starting the session
    private func startSessionWith(urlString: String){
        let config = URLSessionConfiguration.default
        guard let url = URL(string: urlString) else {
            // If the QR did not consist of a valid url
            self.errorReadingQR?()
            return
        }
        
        //establish url session
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .none)
        
        //set task with url
        let dataTask = session.dataTask(with: url, completionHandler: { (data, response, error) in
            // If the direct QR Url doesnot contain a redirection url
            self.errorReadingQR?()
        })
        
        dataTask.resume()
    }
    
    ///  This delegate function gives callback when a HTTP redirection is performerd during a URL session
    ///
    ///  - parameter values: the attributes and values for preparing a brand url
    internal func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        
        // This block fetches the redirected url made from the parent QR url
        let dictValue = response.allHeaderFields
        if let value =  dictValue[attributes.metaKeyForRedirectUrlInSession] as? String, let redirectedUrl = value.removingPercentEncoding{
            self.redirectURL = redirectedUrl
            if self.checkForGenericURL(urlString: self.redirectURL){
                guard let rebrandlyUrl = self.prepareRebrandlyURL(urlString: self.redirectURL) else {return}
                self.startSessionWith(urlString: rebrandlyUrl)
                return
            }
        }
        
        
        if let universalLink = self.getAdjustUniversalLink(url: self.redirectURL), !universalLink.isEmpty{
            self.handleUniversalDeeplink(universalLink: universalLink)
        }else if self.checkRedirectURLForDeeplink(str: redirectURL){
            var fetchValues = self.fetchValues(url: self.redirectURL)
            if let deeplinkUrl = self.prepareUrlFrom(values: fetchValues){
                fetchValues[attributes.keyForDeeplingURL] = deeplinkUrl
                self.getValuesFromUrl?(fetchValues)
            }
        }
        self.handleUniversalDeeplink(universalLink: self.redirectURL)
        
    }
    
    ///  Validate if the url contains a valid Host Name
    ///
    ///  - parameter str: the URL for which validation is performed
    ///  - returns: true if URL is valid else false
    private func checkURLForValidHostNames(str: String) -> Bool{
        return str.contains(attributes.validHostNames)
    }
    
    ///  Validate if the url contains a deepling key value pair
    ///
    ///  - parameter str: the URL for which validation is performed
    ///  - returns: true if found else false
    private func checkRedirectURLForDeeplink(str: String) -> Bool{
        return str.contains(attributes.validQRAttributes)
    }
    
    ///  Prepare a Rebrandly URL
    ///
    ///  - parameter urlString: The Parent URL
    ///  - returns: returns the rebrandly URL
    private func prepareRebrandlyURL(urlString: String) -> String?{
        let values = self.fetchValues(url: urlString)
        if let kfcPath = values[attributes.keyForRebrandlyURL]{
            return "\(QRAppConstants.rebrandlyHost.rawValue)\(kfcPath)"
        }
        return nil
    }
    
    ///  Check if the URL is Generic type
    ///
    ///  - parameter urlString: The url to be validated
    ///  - returns: true if url is a Generic URL else false
    private func checkForGenericURL(urlString: String) -> Bool{
        return urlString.contains(QRAppConstants.genericMobAPIHost.rawValue)
    }
}

extension String {
    ///  Check if the String contains any element from the array as SubString.
    ///
    ///  - parameter strings: The array of string to be checked.
    func contains(_ strings: [String]) -> Bool {
        strings.contains { contains($0) }
    }
}


