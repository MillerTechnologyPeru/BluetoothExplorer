//
//  ServiceEntity.swift
//  
//
//  Created by Alsey Coleman Miller on 11/22/22.
//

import AppIntents
import Bluetooth
import GATT

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct ServiceEntity: AppEntity, Identifiable {
    
    let id: ID
    
    let uuid: String
    
    let isPrimary: Bool
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension ServiceEntity {
    
    struct ID: Equatable, Hashable, EntityIdentifierConvertible, Sendable {
        
        let peripheral: PeripheralEntity.ID
        
        let attributeID: Int
        
        var entityIdentifierString: String {
            return peripheral.description + "/" + attributeID.description
        }

        /// Identifiers should be able to initialize via a `String` format.
        static func entityIdentifier(for string: String) -> ID? {
            let components = string.components(separatedBy: "/")
            guard components.count == 2,
                let peripheral = PeripheralEntity.ID(components[0]),
                let attributeID = Int(components[1]) else {
                return nil
            }
            return ServiceEntity.ID.init(peripheral: peripheral, attributeID: attributeID)
        }
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension ServiceEntity {
    
    init(_ service: Store.Service) {
        self.id = .init(peripheral: service.peripheral.id, attributeID: service.id.hashValue)
        self.uuid = service.uuid.rawValue
        self.isPrimary = service.isPrimary
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
extension ServiceEntity {
    
    static var defaultQuery: ServiceQuery { ServiceQuery() }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Service"
    }
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(BluetoothUUID(rawValue: uuid)?.metadata?.name ?? uuid)",
            subtitle: "Peripheral \(id.peripheral.description)"
        )
    }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct ServiceQuery: EntityQuery {
    
    @MainActor
    func entities(for identifiers: [ServiceEntity.ID]) -> [ServiceEntity] {
        let allServices = BluetoothExplorerApp.store.services.values.lazy.reduce([], { $0 + $1 })
        return identifiers.compactMap { id in
            allServices
                .first(where: { $0.peripheral.id == id.peripheral && $0.id.hashValue == id.attributeID })
                .map { ServiceEntity($0) }
        }
    }
    
    func suggestedEntities() -> [ServiceEntity] { [] }
}
