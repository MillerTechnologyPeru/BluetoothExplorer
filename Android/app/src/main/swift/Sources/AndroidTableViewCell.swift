//
//  AndroidTableViewCell.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 4/30/19.
//  Copyright © 2019 PureSwift. All rights reserved.
//

import Foundation

#if os(Android) || os(macOS)

import Foundation
import Android
import AndroidUIKit
import java_lang

protocol AndroidTableViewCell: ReusableTableViewCell {
    
    static var layout: String { get }
    
    func awakeFromLayout()
}

extension AndroidTableViewCell {
    
    func awakeFromLayout() { }
}

extension AndroidTableViewCell where Self: AndroidUIKit.UITableViewCell {
    
    private func inflate() {
        
        let layout = Self.layout
        
        if self.layoutName != layout {
            inflateAndroidLayout(layout)
            awakeFromLayout()
        }
    }
    
    func view(for identifier: String) -> Android.View.View? {
        
        inflate()
        let activity = UIApplication.shared.androidActivity
        let androidIdentifier = activity.getIdentifier(name: identifier, type: "id")
        return androidView.findViewById(androidIdentifier)
    }
    
    subscript (identifier: String) -> Android.View.View {
        
        guard let view = self.view(for: identifier)
            else { fatalError("No view for \(identifier)") }
        
        return view
    }
}

#endif
