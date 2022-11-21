//
//  ManufacturerDataEntity.swift
//  
//
//  Created by Alsey Coleman Miller on 11/20/22.
//

import AppIntents
import Bluetooth
import GATT

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct ManufacturerDataEntity: AppEntity {
    
    let company: UInt16
    
    let additionalData: Data
    
    var id: String {
        "0x"
        + company.toHexadecimal()
        + additionalData.toHexadecimal()
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension ManufacturerDataEntity {
    
    init(_ manufacturerData: GATT.ManufacturerSpecificData) {
        
        self.company = manufacturerData.companyIdentifier.rawValue
        self.additionalData = manufacturerData.additionalData
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension ManufacturerDataEntity {
    
    static var defaultQuery: ManufacturerDataQuery { ManufacturerDataQuery() }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Manufacturer Data"
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(CompanyIdentifier(rawValue: company).description)",
            subtitle: "0x\(additionalData.toHexadecimal())"
        )
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct ManufacturerDataQuery: EntityQuery {
    
    func entities(for identifiers: [String]) -> [ManufacturerDataEntity] {
        []
    }
    
    @MainActor
    func suggestedEntities() throws -> [ManufacturerDataEntity] {
        return Store.shared.scanResults
            .values
            .lazy
            .compactMap { $0.advertisementData.manufacturerData }
            .map { .init($0) }
    }
}
