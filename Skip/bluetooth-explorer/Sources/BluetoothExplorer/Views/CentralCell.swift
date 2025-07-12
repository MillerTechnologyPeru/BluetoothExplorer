//
//  CentralCell.swift
//  
//
//  Created by Alsey Coleman Miller on 18/12/21.
//

import SwiftUI
import BluetoothExplorerModel

public struct CentralCell: View {
        
    let item: CentralListViewModel.ScanResult
    
    public init(_ item: CentralListViewModel.ScanResult) {
        self.item = item
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 2.0) {
            Text(verbatim: item.name)
                .font(.title3)
                .foregroundColor(.primary)
            #if DEBUG
            Text(verbatim: item.id)
                .font(.footnote)
                .foregroundColor(.secondary)
            #endif
            if let beacon = item.beacon {
                Text(verbatim: beacon.uuid)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(verbatim: beacon.major)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(verbatim: beacon.minor)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(verbatim: beacon.rssi)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            if let company = item.company, item.beacon == nil {
                Text(verbatim: company)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            if let services = item.services {
                Text(verbatim: services)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .padding()
    }
}
