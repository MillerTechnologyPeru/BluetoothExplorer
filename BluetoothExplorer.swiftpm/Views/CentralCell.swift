//
//  .swift
//  
//
//  Created by Alsey Coleman Miller on 18/12/21.
//

import SwiftUI
import Bluetooth
import GATT

struct CentralCell <Peripheral: Peer, Advertisement: AdvertisementData> : View {
    
    let scanData: ScanData<Peripheral, Advertisement>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2.0) {
            if name == nil, company == nil {
                Text(verbatim: scanData.peripheral.description)
            } else {
                if let name = self.name {
                    Text(verbatim: name)
                }
                if let company = self.company {
                    Text(verbatim: company)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }.padding()
    }
}

extension CentralCell {
    
    var name: String? {
        scanData.advertisementData.localName
    }
    
    var company: String? {
        scanData.advertisementData.manufacturerData?.companyIdentifier.name
    }
    
    
}

#if DEBUG
struct CentralCell_Preview: PreviewProvider {
    static var previews: some View {
        CentralCell(scanData: MockScanData.beacon)
    }
}
#endif
