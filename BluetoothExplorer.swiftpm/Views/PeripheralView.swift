//
//  PeripheralView.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 31/10/21.
//  Copyright © 2021 Alsey Coleman Miller. All rights reserved.
//

import SwiftUI
import Bluetooth
import GATT

struct PeripheralView: View {
    
    @Environment(Store.self)
    var store: Store
    
    let peripheral: Store.Peripheral
    
    @State
    var isRefreshing = false
    
    var body: some View {
        List {
            if let scanData = store.scanResults[peripheral]?.scanData {
                if let manufacturerData = scanData.advertisementData.manufacturerData {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: manufacturerData.companyIdentifier.name ?? manufacturerData.companyIdentifier.description)
                        if manufacturerData.additionalData.isEmpty == false {
                            Text(verbatim: "0x" + manufacturerData.additionalData.toHexadecimal())
                        }
                        Text("Manufacturer Data")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                if let serviceUUIDs = scanData.advertisementData.serviceUUIDs,
                    serviceUUIDs.isEmpty == false {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: ListFormatter().string(from: serviceUUIDs.map({ $0.rawValue })) ?? "")
                        Text("Service UUIDs")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            if services.isEmpty == false {
                Section(content: {
                    ForEach(services) { service in
                        NavigationLink(destination: {
                            ServiceView(
                                service: service
                            )
                        }, label: {
                            AttributeCell(uuid: service.uuid)
                        })
                    }
                }, header: {
                    Text("Services")
                })
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarItems(trailing: leftBarButtonItem)
        #endif
        .task {
            if services.isEmpty {
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

extension PeripheralView {
    
    var title: String {
        store.scanResults[peripheral]?.name ?? "Device"
    }
    
    var isConnected: Bool {
        //store.connected.contains(peripheral)
        true
    }
    
    var services: [Store.Service] {
        store.services[peripheral] ?? []
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
        } else if isConnected {
            return AnyView(Button(action: {
                assert(Thread.isMainThread)
                Task {
                    await store.disconnect(peripheral)
                }
            }) {
                Text("Disconnect")
            })
        } else {
            return AnyView(Button(action: {
                Task {
                    assert(Thread.isMainThread)
                    await connect()
                    assert(Thread.isMainThread)
                }
            }) {
                Text("Connect")
            })
        }
    }
    
    func connect() async {
        do {
            if isConnected == false {
                try await store.connect(to: peripheral)
            }
        }
        catch {
            print("Unable to connect", error)
            return
        }
    }
    
    func reload() async {
        do {
            if isConnected == false {
                try await store.connect(to: peripheral)
            }
            try await store.discoverServices(for: peripheral)
        }
        catch { print("Unable to load services", error) }
    }
}

#if DEBUG && targetEnvironment(simulator)
struct PeripheralView_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                PeripheralView(
                    peripheral: .beacon
                )
            }
            .environment(Store())
        }
    }
}
#endif
