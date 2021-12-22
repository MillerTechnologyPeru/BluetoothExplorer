//
//  CharacteristicView.swift
//  
//
//  Created by Alsey Coleman Miller on 22/12/21.
//

import SwiftUI
import Bluetooth
import GATT

struct CharacteristicView: View {
    
    @StateObject
    var store: Store
    
    let characteristic: NativeCharacteristic
    
    @State
    var isRefreshing = false
    
    var body: some View {
        List {
            VStack(alignment: .leading, spacing: nil) {
                Text(verbatim: characteristic.uuid.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                ForEach(characteristic.properties.sorted(by: { $0.rawValue > $1.rawValue }), id: \.rawValue) {
                    Text(verbatim: $0.description)
                }
            }
            if descriptors.isEmpty == false {
                Section(content: {
                    ForEach(descriptors) { descriptor in
                        NavigationLink(destination: {
                            Text(descriptor.uuid.description)
                        }, label: {
                            AttributeCell(uuid: descriptor.uuid)
                        })
                    }
                }, header: {
                    Text("Descriptors")
                })
            }
        }
        .navigationTitle(title)
        .navigationBarItems(trailing: leftBarButtonItem)
        .task {
            if descriptors.isEmpty {
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

extension CharacteristicView {
    
    var title: String {
        characteristic.uuid.name ?? "Characteristic"
    }
    
    var peripheral: NativePeripheral {
        characteristic.peripheral
    }
    
    var isConnected: Bool {
        store.connected.contains(peripheral)
    }
    
    var descriptors: [Store.Descriptor] {
        store.descriptors[characteristic] ?? []
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
            try await store.discoverDescriptors(for: characteristic)
        }
        catch { print("Unable to load descriptors", error) }
    }
}
