//
//  CentralCell.swift
//  
//
//  Created by Alsey Coleman Miller on 18/12/21.
//

import SwiftUI
import Bluetooth
import GATT

struct CentralCell <Peripheral: Peer, Advertisement: AdvertisementData> : View {
        
    let scanData: ScanDataCache<Peripheral, Advertisement>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2.0) {
            nameText
                .font(.title3)
                .foregroundColor(.primary)
            #if DEBUG
            Text(verbatim: scanData.id.description)
                .font(.footnote)
                .foregroundColor(.secondary)
            #endif
            if let beacon = self.beacon {
                Text("\(beacon.uuid)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text("Major: 0x\(beacon.major.toHexadecimal())")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text("Minor: 0x\(beacon.minor.toHexadecimal())")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text("RSSI: \(beacon.rssi)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            if let company = self.company, beacon == nil {
                Text(verbatim: company)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            if let services = services {
                Text("Services: \(services)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .padding()
    }
}

private struct CentralCellCache {
    static let listFormatter = ListFormatter()
}

extension CentralCell {
    
    var nameText: Text {
        scanData.name.flatMap { Text(verbatim: $0) } ?? (beacon != nil ? Text("iBeacon") : Text("Unknown"))
    }
    
    var company: String? {
        scanData.manufacturerData?.companyIdentifier.name
    }
    
    var services: String? {
        let services = scanData.serviceUUIDs
            .sorted(by: { $0.description < $1.description })
            .map { $0.name ?? $0.rawValue }
        guard services.isEmpty == false
            else { return nil }
        return CentralCellCache.listFormatter.string(from: services)
    }
    
    var beacon: AppleBeacon? {
        return scanData.beacon
    }
}

#if DEBUG
struct CentralCell_Preview: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                CentralCell(scanData: .init(scanData: MockScanData.beacon))
                CentralCell(scanData: .init(scanData: MockScanData.beacon))
                CentralCell(scanData: .init(scanData: MockScanData.beacon))
                CentralCell(scanData: .init(scanData: MockScanData.smartThermostat))
            }
        }
    }
}
#endif
