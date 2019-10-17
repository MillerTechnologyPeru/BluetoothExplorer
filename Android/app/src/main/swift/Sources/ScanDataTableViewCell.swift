//
//  ScanDataTableViewCell.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 4/30/19.
//  Copyright © 2019 PureSwift. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#elseif os(Android) || os(macOS)
import Android
import AndroidUIKit
import java_lang
#endif

/// Table View Cell
final class ScanDataTableViewCell: UITableViewCell {
    
    #if os(iOS)
    
    #elseif os(Android) || os(macOS)
    
    var titleLabel: Android.Widget.TextView! {
        
        return Android.Widget.TextView(casting: self["textLabel"])
    }
    
    var detailLabel: Android.Widget.TextView! {
        
        return Android.Widget.TextView(casting: self["detailTextLabel"])
    }
    
    var accessoryImageView: Android.Widget.ImageView! {
        
        return Android.Widget.ImageView(casting: self["accessoryImageView"])
    }
    
    var isAccessoryVisible: Bool = false {
        didSet { accessoryImageView.visibility = isAccessoryVisible ? .visible : .invisible }
    }
    
    #endif
}

// MARK: - ReusableTableViewCell

extension ScanDataTableViewCell: ReusableTableViewCell {
    static let reuseIdentifier = "ScanDataTableViewCell"
}

#if os(iOS)
extension ScanDataTableViewCell: NibTableViewCell { }
#elseif os(Android) || os(macOS)
extension ScanDataTableViewCell: AndroidTableViewCell {
    static let layout = "cell_right_detail"
    
    func awakeFromLayout() {
        
    }
}
#endif
