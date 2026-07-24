//
//  PeripheralView.swift
//  BluetoothExplorer
//
//  Created by Alsey Coleman Miller on 31/10/21.
//  Copyright © 2021 Alsey Coleman Miller. All rights reserved.
//

#if canImport(SwiftUI)
import SwiftUI
#else
import AndroidSwiftUI
#endif
import BluetoothExplorerModel
import BluetoothExplorerPluginEngine

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
                        Text(verbatim: manufacturerData.companyIdentifier.rawValue.description)
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
                        Text(verbatim: serviceUUIDs.reduce("", { $0 + ($0.isEmpty ? "" : ", ") + $1.rawValue }))
                        Text("Service UUIDs")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            let decoded = store.decodedAdvertisement(for: peripheral)
            if decoded.isEmpty == false {
                Section(content: {
                    ForEach(Array(decoded.enumerated()), id: \.offset) { _, result in
                        DecodedFieldsView(result: result)
                    }
                }, header: {
                    Text("Decoded")
                })
            }
            if isConnected {
                Section(content: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: mtuText)
                        Text("Maximum Transmission Unit")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: connectedRSSIText)
                        Text("Signal Strength")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Button(action: {
                        Task { await readConnectionInfo() }
                    }) {
                        Text("Refresh")
                    }
                }, header: {
                    Text("Connection")
                })
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
        .toolbar {
            leftBarButtonItem
        }
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
        store.connected.contains(peripheral)
    }
    
    var services: [Store.Service] {
        store.services[peripheral] ?? []
    }

    var mtuText: String {
        store.maximumTransmissionUnit[peripheral].map { $0.rawValue.description } ?? "—"
    }

    /// Read from the connected peripheral, unlike the RSSI carried in an advertisement.
    var connectedRSSIText: String {
        store.rssi[peripheral].map { "\($0.rawValue) dBm" } ?? "—"
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
        await readConnectionInfo()
    }

    /// Read the MTU and signal strength of the live connection. Best-effort: a peripheral that
    /// drops out mid-read should not blank out the services already discovered.
    ///
    /// Deliberately not gated on `isConnected`: that flag is refreshed asynchronously, so it still
    /// reads false right after `connect()` returns. The central throws `.disconnected` if the link
    /// really is down, which is caught below.
    func readConnectionInfo() async {
        do {
            try await store.maximumTransmissionUnit(for: peripheral)
            try await store.rssi(for: peripheral)
        }
        catch { print("Unable to read connection info", error) }
    }
}
