//
//  CharacteristicEntity.swift
//  
//
//  Created by Alsey Coleman Miller on 11/22/22.
//

import AppIntents
import Bluetooth
import GATT

/// Characteristic Entity
@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct CharacteristicEntity: AppEntity, Identifiable {
    
    let id: ID
    
    let uuid: String
    
    let properties: UInt8
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension CharacteristicEntity {
    
    struct ID: Equatable, Hashable, EntityIdentifierConvertible, Sendable {
        
        let peripheral: UUID
        
        let attributeID: Int
        
        var entityIdentifierString: String {
            return peripheral.uuidString + "/" + attributeID.description
        }
        
        static func entityIdentifier(for string: String) -> ID? {
            let components = string.components(separatedBy: "/")
            guard components.count == 2,
                let peripheral = UUID(uuidString: components[0]),
                let attributeID = Int(components[1]) else {
                return nil
            }
            return CharacteristicEntity.ID.init(peripheral: peripheral, attributeID: attributeID)
        }
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension CharacteristicEntity {
    
    init(_ characteristic: Store.Characteristic) {
        self.id = .init(peripheral: characteristic.peripheral.id, attributeID: characteristic.id.hashValue)
        self.uuid = characteristic.uuid.rawValue
        self.properties = characteristic.properties.rawValue
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension CharacteristicEntity {
    
    static var defaultQuery: CharacteristicQuery { CharacteristicQuery() }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Characteristic"
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(BluetoothUUID(rawValue: uuid)?.name ?? uuid)",
            subtitle: """
                Peripheral \(id.peripheral.description)
                Properties \(BitMaskOptionSet<Store.Characteristic.Property>.init(rawValue: properties).description)
            """
        )
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct CharacteristicQuery: EntityQuery {
    
    @MainActor
    func entities(for identifiers: [CharacteristicEntity.ID]) -> [CharacteristicEntity] {
        let allServices = Store.shared.characteristics.values.lazy.reduce([], { $0 + $1 })
        return identifiers.compactMap { id in
            allServices
                .first(where: { $0.peripheral.id == id.peripheral && $0.id.hashValue == id.attributeID })
                .map { CharacteristicEntity($0) }
        }
    }
    
    func suggestedEntities() -> [CharacteristicEntity] { [] }
}
