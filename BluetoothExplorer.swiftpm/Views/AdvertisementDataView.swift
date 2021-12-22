//
//  AdvertisementView.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 31/10/21.
//  Copyright © 2021 Alsey Coleman Miller. All rights reserved.
//

import SwiftUI
import Bluetooth
import GATT
import DarwinGATT

struct AdvertisementDataView <Advertisement: AdvertisementData> : View {
    
    let advertisementData: Advertisement
    
    var body: some View {
        VStack(alignment: .leading, spacing: nil) {
            if let localName = advertisementData.localName {
                HStack {
                    Text("Name")
                    Text(verbatim: localName)
                }
            }
            if let manufacturerData = advertisementData.manufacturerData {
                HStack {
                    Text("Manufacturer Data")
                    VStack {
                        if let name = manufacturerData.companyIdentifier.name {
                            Text(verbatim: name)
                        }
                        Text(verbatim: (manufacturerData.additionalData as NSData).description)
                    }
                }
            }
        }
    }
}

#if DEBUG
struct AdvertisementDataView_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            AdvertisementDataView(
                advertisementData: MockAdvertisementData.beacon
            ).previewLayout(.sizeThatFits)
            AdvertisementDataView(
                advertisementData: MockAdvertisementData.beacon
            )
        }
    }
}
#endif
