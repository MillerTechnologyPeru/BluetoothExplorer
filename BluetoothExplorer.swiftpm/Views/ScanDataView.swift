//
//  ScanDataView.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 31/10/21.
//  Copyright © 2021 Alsey Coleman Miller. All rights reserved.
//

import SwiftUI
import Bluetooth
import GATT

struct ScanDataView <Peripheral: Peer, Advertisement: AdvertisementData> : View {
    
    let scanData: ScanData<Peripheral, Advertisement>
    
    var body: some View {
        VStack(alignment: .leading, spacing: nil) {
            Text(verbatim: scanData.peripheral.description)
            HStack {
                Text("Date")
                Text(verbatim: string(from: scanData.date))
            }
            AdvertisementDataView(advertisementData: scanData.advertisementData)
        }
    }
}

struct ScanDataViewCache {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

extension ScanDataView {
    
    func string(from date: Date) -> String {
        return ScanDataViewCache.dateFormatter.string(from: date)
    }
}

#if DEBUG
struct ScanDataView_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            ScanDataView(
                scanData: MockScanData.beacon
            )
            ScanDataView(
                scanData: MockScanData.beacon
            )
        }
    }
}
#endif
