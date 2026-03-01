//
//  PeripheralEntity.swift
//  
//
//  Created by Alsey Coleman Miller on 11/20/22.
//

#if canImport(AppIntents)
import AppIntents
import Bluetooth
import GATT

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct PeripheralEntity: AppEntity, Identifiable {
    
    let id: NativeCentral.Peripheral.ID
    
    /// Timestamp for when device was scanned.
    let date: Date
    
    /// The current received signal strength indicator (RSSI) of the peripheral, in decibels.
    let rssi: Double
    
    /// A Boolean value that indicates whether the advertising event type is connectable.
    let isConnectable: Bool
    
    /// The local name of a peripheral.
    let name: String?
    
    /// The Manufacturer data of a peripheral.
    let manufacturerData: ManufacturerDataEntity?
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension PeripheralEntity {
    
    init(_ scanResult: Store.ScanData) {
        self.id = scanResult.id
        self.date = scanResult.date
        self.rssi = scanResult.rssi
        self.isConnectable = scanResult.isConnectable
        self.name = scanResult.advertisementData.localName
        self.manufacturerData = scanResult.advertisementData.manufacturerData.map { ManufacturerDataEntity($0) }
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension PeripheralEntity {
    
    static var defaultQuery: PeripheralQuery { PeripheralQuery() }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Peripheral"
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(id.description)",
            subtitle: "\(self.subtitle ?? "")"
        )
    }
    
    private var subtitle: String? {
        var name = ""
        name += self.name ?? ""
        if let company = manufacturerData.flatMap({ CompanyIdentifier(rawValue: $0.company).name }) {
            name += name.isEmpty ? "" : " - " + company
        }
        return name
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct PeripheralQuery: EntityQuery {
    
    @MainActor
    func entities(for identifiers: [PeripheralEntity.ID]) -> [PeripheralEntity] {
        let scanResults = BluetoothExplorerApp.store.scanResults.values
        return identifiers.compactMap { id in
            scanResults.first(where: { $0.id == id })
                .map { PeripheralEntity($0.scanData) }
        }
    }
    
    @MainActor
    func suggestedEntities() throws -> [PeripheralEntity] {
        BluetoothExplorerApp.store.scanResults
            .values
            .sorted(by: { ($0.name ?? $0.id.description) < ($1.name ?? $1.id.description) })
            .map { .init($0.scanData) }
    }
}

// MARK: - EntityIdentifierConvertible

extension BluetoothAddress: @retroactive EntityIdentifierConvertible {
    
    public var entityIdentifierString: String {
        rawValue
    }
    
    public static func entityIdentifier(for entityIdentifierString: String) -> Bluetooth.BluetoothAddress? {
        .init(rawValue: entityIdentifierString)
    }
}
#endif
