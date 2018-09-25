//
//  PeripheralCell.swift
//  Android
//
//  Created by Marco Estrella on 9/25/18.
//

import Foundation
import Bluetooth
import GATT

#if os(Android) || os(macOS)
import Android
import AndroidUIKit
import java_swift

public class PeripheralCell: UITableViewCell {
    
    var itemView: AndroidView?
    var tvName: AndroidTextView?
    var tvAddress: AndroidTextView?
    
    public required init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        let peripheralViewLayoutId = UIApplication.shared.androidActivity.getIdentifier(name: "peripheral_item", type: "layout")
        
        let tvNameId = UIApplication.shared.androidActivity.getIdentifier(name: "tvName", type: "id")
        let tvAddressId = UIApplication.shared.androidActivity.getIdentifier(name: "tvAddress", type: "id")
        
        let layoutInflarer = Android.View.LayoutInflater.from(context: UIApplication.shared.androidActivity)
        
        itemView = layoutInflarer.inflate(resource: Android.R.Layout(rawValue: peripheralViewLayoutId), root: nil, attachToRoot: false)
        
        guard let tvNameObject = itemView?.findViewById(tvNameId)
            else { fatalError("No view for \(tvNameId)") }
        
        guard let tvAddressObject = itemView?.findViewById(tvAddressId)
            else { fatalError("No view for \(tvAddressId)") }
        
        self.tvName = Android.Widget.TextView(casting: tvNameObject)
        self.tvAddress = Android.Widget.TextView(casting: tvAddressObject)
        
        self.viewHolder = PeripheralCellViewHolder.init(cell: self)
    }
}

internal class PeripheralCellViewHolder: UITableViewCellViewHolder {
    
    fileprivate convenience init(cell: PeripheralCell) {
        
        self.init(javaObject: nil)
        bindNewJavaObject(itemView: cell.itemView!)
        
        self.cell = cell
    }
    
    required init(javaObject: jobject?) {
        super.init(javaObject: javaObject)
    }
    
    deinit {
        NSLog("\(type(of: self)) \(#function)")
    }
}

#endif
