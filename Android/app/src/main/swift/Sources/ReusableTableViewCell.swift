//
//  ReusableTableViewCell.swift
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

/// Reusable Table View Cell
protocol ReusableTableViewCell: class {
    
    /// Reusable Cell Identifier
    static var reuseIdentifier: String { get }
    
    /// Register table view cell for reuse.
    static func register(tableView: UITableView)
}

#if os(iOS)
extension ReusableTableViewCell where Self: UITableViewCell {
    
    static func register(tableView: UITableView) {
        
        tableView.register(self, forCellReuseIdentifier: reuseIdentifier)
    }
}
#else
extension ReusableTableViewCell {
    
    static func register(tableView: UITableView) {
        
        tableView.register(self as? UITableViewCell.Type, forCellReuseIdentifier: reuseIdentifier)
    }
}
#endif

extension UITableView {
    
    func dequeueReusableCell <T: ReusableTableViewCell> (_ cell: T.Type, for indexPath: IndexPath) -> T {
        
        let cell = dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath)
        
        guard let reusableCell = cell as? T
            else { fatalError("Invalid cell \(cell) for \(T.reuseIdentifier)") }
        
        return reusableCell
    }
}

extension UITableView {
    
    func register <T: ReusableTableViewCell> (_ cell: T.Type) {
        
        T.register(tableView: self)
    }
}
