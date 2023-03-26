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
    
    let scanData: ScanData<Peripheral, Advertisement>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2.0) {
            Text(verbatim: name)
                .font(.title3)
                .foregroundColor(.primary)
            if let beacon = self.beacon {
                Text("\(beacon.uuid)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text("Major: \(beacon.major)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text("Minor: \(beacon.minor)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text("RSSI: \(beacon.rssi)")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            #if DEBUG
            Text(verbatim: scanData.peripheral.description)
                .font(.footnote)
                .foregroundColor(.secondary)
            #endif
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
    
    var name: String {
        scanData.advertisementData.localName ?? (beacon != nil ? "iBeacon" : "Unknown")
    }
    
    var company: String? {
        scanData.advertisementData.manufacturerData?.companyIdentifier.name
    }
    
    var services: String? {
        let services = (scanData.advertisementData.serviceUUIDs ?? [])
            .sorted(by: { $0.description < $1.description })
            .map { $0.name ?? $0.rawValue }
        guard services.isEmpty == false
            else { return nil }
        return CentralCellCache.listFormatter.string(from: services)
    }
    
    var beacon: AppleBeacon? {
        return scanData.advertisementData.manufacturerData.flatMap { AppleBeacon(manufacturerData: $0) }
    }
}

#if DEBUG
struct CentralCell_Preview: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                CentralCell(scanData: MockScanData.beacon)
                CentralCell(scanData: MockScanData.beacon)
                CentralCell(scanData: MockScanData.beacon)
                CentralCell(scanData: MockScanData.smartThermostat)
            }
        }
    }
}
#endif
