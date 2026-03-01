//
//  DescriptorView.swift
//  
//
//  Created by Alsey Coleman Miller on 23/12/21.
//

#if canImport(SwiftUI)
import SwiftUI
import Bluetooth
import GATT

struct DescriptorView: View {
    
    @Environment(Store.self)
    var store: Store
    
    let descriptor: Store.Descriptor
    
    @State
    var isRefreshing = false
    
    @State
    var showSheet = false
    
    var body: some View {
        List {
            VStack(alignment: .leading, spacing: nil) {
                Text(verbatim: descriptor.uuid.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            if actions.isEmpty == false {
                Section {
                    if canPerform(.read) {
                        Button("Read") {
                            Task { await read() }
                        }
                    }
                    if canPerform(.write) {
                        Button("Write") {
                            showSheet = true
                        }
                    }
                }
            }
            if values.isEmpty == false {
                AttributeValuesSection(
                    uuid: descriptor.uuid,
                    values: values
                )
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarItems(trailing: leftBarButtonItem)
        #endif
        .task {
            if values.isEmpty {
                await reload()
            }
        }
        .refreshable {
            isRefreshing = true
            await reload()
            isRefreshing = false
        }
        .sheet(
            isPresented: $showSheet,
            onDismiss: { },
            content: {
                WriteAttributeView(
                    uuid: descriptor.uuid,
                    text: values.last?.data.toHexadecimal() ?? "",
                    cancel: {
                        showSheet = false
                    },
                    done: { data in
                        showSheet = false
                        Task {
                            await write(data)
                        }
                    }
                )
            })
    }
}

extension DescriptorView {
    
    enum Action: CaseIterable {
        case write
        case read
    }
    
    func canPerform(_ action: Action) -> Bool {
        switch (descriptor.uuid, action) {
        case (BluetoothUUID.Descriptor.clientCharacteristicConfiguration, .write):
            return false
        case (BluetoothUUID.Descriptor.serverCharacteristicConfiguration, .write):
            return false
        case (BluetoothUUID.Descriptor.characteristicPresentationFormat, .write):
            return false
        case (BluetoothUUID.Descriptor.characteristicAggregateFormat, .write):
            return false
        case (BluetoothUUID.Descriptor.characteristicExtendedProperties, .write):
            return false
        case (BluetoothUUID.Descriptor.characteristicUserDescription, _):
            return true
        default:
            return true
        }
    }
    
    var actions: [Action] {
        return Action.allCases
            .filter { canPerform($0) }
    }
}

extension DescriptorView {
    
    var title: String {
        descriptor.uuid.metadata?.name ?? "Descriptor"
    }
    
    var peripheral: Store.Peripheral {
        descriptor.peripheral
    }
    
    var isConnected: Bool {
        // FIXME
        //store.connected.contains(peripheral)
        false
    }
    
    var showActivity: Bool {
        store.activity[peripheral] ?? false
    }
    
    var values: [AttributeValue] {
        store.descriptorValues[descriptor]?
            .values
            .sorted(by: { $0.date > $1.date })
        ?? []
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
        // read value if possible
        if values.isEmpty {
            if canPerform(.read) {
                await read()
            }
        }
    }
    
    func read() async {
        do {
            if isConnected == false {
                try await store.connect(to: peripheral)
            }
            try await store.readValue(for: descriptor)
        }
        catch { print("Unable to read descriptor", error) }
    }
    
    func write(_ data: Data) async {
        do {
            if isConnected == false {
                try await store.connect(to: peripheral)
            }
            try await store.writeValue(data, for: descriptor)
        }
        catch { print("Unable to write decriptor", error) }
    }
}

#if DEBUG && targetEnvironment(simulator)
struct DescriptorView_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                DescriptorView(
                    descriptor: .clientCharacteristicConfiguration(.beacon)
                )
                .environment(Store())
            }
        }
    }
}
#endif

#endif
