//
//  GATTAlertCategory.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/28/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation
import Bluetooth
import Rswift

extension GATTAlertCategory {
    
    var name: String {
        
        switch self {
        case .simpleAlert:
            return R.string.localizable.gattAlertCategorySimpleAlert()
            
        case .email:
            return R.string.localizable.gattAlertCategoryEmail()
            
        case .news:
            return R.string.localizable.gattAlertCategoryNews()
            
        case .call:
            return R.string.localizable.gattAlertCategoryCall()
            
        case .missedCall:
            return R.string.localizable.gattAlertCategoryMissedCall()
            
        case .sms:
            return R.string.localizable.gattAlertCategorySMS()
            
        case .voiceMail:
            return R.string.localizable.gattAlertCategoryVoiceMail()
            
        case .schedule:
            return R.string.localizable.gattAlertCategorySchedule()
            
        case .highPrioritizedAlert:
            return R.string.localizable.gattAlertCategoryHighPrioritized()
            
        case .instantMessage:
            return R.string.localizable.gattAlertCategoryInstantMessage()
        }
    }
    
}
