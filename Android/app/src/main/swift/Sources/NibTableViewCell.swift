//
//  NibTableViewCell.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 4/30/19.
//  Copyright © 2019 PureSwift. All rights reserved.
//

#if os(iOS)
import Foundation
import UIKit

/// NIB loading table view cell
protocol NibTableViewCell: ReusableTableViewCell {
    
    static var nibName: String { get }
}

extension NibTableViewCell {
    
    static var nibName: String {
        
        return reuseIdentifier
    }
}

extension NibTableViewCell {
    
    static func register(tableView: UITableView) {
        
        let bundle = Bundle(for: self)
        let nib = UINib(nibName: nibName, bundle: bundle)
        tableView.register(nib, forCellReuseIdentifier: reuseIdentifier)
    }
}

#endif
