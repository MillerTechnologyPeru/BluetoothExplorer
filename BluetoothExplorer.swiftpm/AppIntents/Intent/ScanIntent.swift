//
//  ScanIntent.swift
//  
//
//  Created by Alsey Coleman Miller on 11/20/22.
//

import AppIntents
import SwiftUI
import Bluetooth
import GATT

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct ScanIntent: AppIntent {
    
    static var title: LocalizedStringResource { "Bluetooth scan" }
    
    static var description: IntentDescription {
        IntentDescription(
            "Scan for nearby Bluetooth devices",
            categoryName: "Utility",
            searchKeywords: ["scan", "bluetooth"]
        )
    }
    
    @Parameter(
        title: "Duration",
        description: "Duration in seconds for scanning.",
        default: 1
    )
    var duration: Int
    
    @Parameter(
        title: "Filter duplicates",
        description: "A Boolean value that specifies whether the scan should run with duplicate filtering.",
        default: true
    )
    var filterDuplicates: Bool
    
    @Parameter(
        title: "Services",
        description: "Service UUID to filter advertisements by.",
        default: []
    )
    var services: [String]
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let services = Set(self.services.compactMap({ BluetoothUUID(rawValue: $0) }))
        let store = Store.shared
        try await store.central.wait(for: .poweredOn, warning: 1, timeout: 2)
        try await store.scan(
            with: services,
            filterDuplicates: filterDuplicates
        )
        try await Task.sleep(for: .seconds(duration))
        await store.stopScan()
        let peripherals = store.scanResults
            .values
            .sorted(by: { $0.peripheral.id.description < $1.peripheral.id.description })
            .map { PeripheralEntity($0) }
        return .result(
            value: peripherals,
            view: view(for: peripherals)
        )
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
@MainActor
private extension ScanIntent {
    
    func view(for results: [PeripheralEntity]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                if results.isEmpty {
                    Text("No devices found.")
                        .padding(20)
                } else {
                    if results.count > 3 {
                        Text("Found \(results.count) devices.")
                            .padding(20)
                    } else {
                        ForEach(results) {
                            view(for: $0)
                                .padding(8)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
    
    func view(for peripheral: PeripheralEntity) -> some View {
        let name = peripheral.name
        let company = peripheral.manufacturerData.flatMap({ CompanyIdentifier(rawValue: $0.company).name })
        return VStack(alignment: .leading, spacing: 2.0) {
            if name == nil, company == nil {
                Text(verbatim: peripheral.id.description)
            } else {
                if let name = name {
                    Text(verbatim: name)
                }
                if let company = company {
                    Text(verbatim: company)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }.padding()
    }
}
