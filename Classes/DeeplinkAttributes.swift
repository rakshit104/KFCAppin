//
//  DeeplinkAttributes.swift
//  Americana
//
//  Created by appinventiv on 03/02/21.
//  Copyright © 2021 ambrish. All rights reserved.
//

import UIKit

enum QRAppConstants: String{
    case urlScheme = "kfcme"
    case rebrandlyHost = "https://rebrand.ly/"
    case genericMobAPIHost = "mobapi.americana-food.com"
    case rebrandlyURL = "rebrand.ly"
}

struct DeeplinkAttributes {
    var validQRAttributes: [String] = ["deeplink", "deep_link"] // such as "deeplink or deep_link"
    var validHostNames: [String] = ["app.adjust.com", "n8du.adj.st"] // for validation purposes host == "app.adjust.com" || host == "n8du.adj.st"
    var keyForRebrandlyURL : String = "kfc"
    var keyForDeeplingURL : String = "deeplinkUrl"
    var validAddressSubtypeOfUrl : String = "pickupHome"
    var keyForPreparingURLFromDict : String = "deep_link"
    var removeValuesForKeyInPrepareURL : [String] = ["url", "deep_link"]
    var metaKeyForRedirectUrlInSession : String = "Location"
    var currentCountry : String = "UAE"
    
    init() {
    }
    
    init(validQRAttributes: [String], validHostNames: [String], keyForRebrandlyURL : String, keyForDeeplingURL : String,
         validAddressSubtypeOfUrl : String, keyForPreparingURLFromDict : String, removeValuesForKeyInPrepareURL : [String], metaKeyForRedirectUrlInSession : String){
        self.validQRAttributes = validQRAttributes
        self.validHostNames = validHostNames
        self.keyForRebrandlyURL = keyForRebrandlyURL
        self.keyForDeeplingURL = keyForDeeplingURL
        self.validAddressSubtypeOfUrl = validAddressSubtypeOfUrl
        self.keyForPreparingURLFromDict = keyForPreparingURLFromDict
        self.removeValuesForKeyInPrepareURL = removeValuesForKeyInPrepareURL
        self.metaKeyForRedirectUrlInSession = metaKeyForRedirectUrlInSession
    }
}
