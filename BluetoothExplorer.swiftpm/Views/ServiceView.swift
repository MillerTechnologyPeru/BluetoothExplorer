//
//  ServiceView.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

import SwiftUI
import Bluetooth
import GATT

struct ServiceView: View {
    
    @StateObject
    var store: Store
    
    let service: Store.Service
    
    @State
    var isRefreshing = false
    
    var body: some View {
        List {
            VStack(alignment: .leading, spacing: nil) {
                Text(verbatim: service.uuid.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                if service.isPrimary == false {
                    Text("Secondary Service")
                }
            }
            if includedServices.isEmpty == false {
                Section(content: {
                    ForEach(includedServices) { service in
                        NavigationLink(destination: {
                            ServiceView(
                                store: store,
                                service: service
                            )
                        }, label: {
                            AttributeCell(uuid: service.uuid)
                        })
                    }
                }, header: {
                    Text("Included Services")
                })
            }
            if characteristics.isEmpty == false {
                Section(content: {
                    ForEach(characteristics) { characteristic in
                        NavigationLink(destination: {
                            CharacteristicView(
                                store: store,
                                characteristic: characteristic
                            )
                        }, label: {
                            AttributeCell(uuid: characteristic.uuid)
                        })
                    }
                }, header: {
                    Text("Characteristics")
                })
            }
        }
        .navigationTitle(title)
        .navigationBarItems(trailing: leftBarButtonItem)
        .task {
            if characteristics.isEmpty {
                await reload()
            }
        }
        .refreshable {
            isRefreshing = true
            await reload()
            isRefreshing = false
        }
    }
}

extension ServiceView {
    
    var title: String {
        service.uuid.name ?? "Service"
    }
    
    var peripheral: Store.Peripheral {
        service.peripheral
    }
    
    var isConnected: Bool {
        store.connected.contains(peripheral)
    }
    
    var characteristics: [Store.Characteristic] {
        store.characteristics[service] ?? []
    }
    
    var includedServices: [Store.Service] {
        store.includedServices[service] ?? []
    }
    
    var showActivity: Bool {
        store.activity[peripheral] ?? false
    }
    
    var leftBarButtonItem: some View {
        if showActivity, isRefreshing == false {
            return AnyView(
                ProgressView()
                    .progressViewStyle(.circular)
            )
        } else {
            return AnyView(
                EmptyView()
            )
        }
    }
    
    func reload() async {
        do {
            if isConnected == false {
                try await store.connect(to: peripheral)
            }
            try await store.discoverIncludedServices(for: service)
            try await store.discoverCharacteristics(for: service)
        }
        catch { print("Unable to load characteristics", error) }
    }
}

#if DEBUG && targetEnvironment(simulator)
struct ServiceView_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ServiceView(
                    store: .shared,
                    service: .deviceInformation
                )
            }
        }
    }
}
#endif
