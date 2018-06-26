//
//  String.swift
//  BluetoothExplorer
//
//  Created by Carlos Duclos on 6/26/18.
//  Copyright © 2018 PureSwift. All rights reserved.
//

import Foundation

public extension String {
    
    func text(before text: String) -> String? {
        guard let range = self.range(of: text) else { return nil }
        return String(self[self.startIndex..<range.lowerBound])
    }
}
