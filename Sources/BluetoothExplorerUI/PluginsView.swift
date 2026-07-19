//
//  PluginsView.swift
//  BluetoothExplorerUI
//
//  Lists loaded parser plugins with enable/disable toggles and load-error surfacing.
//

import SwiftUI
import BluetoothExplorerModel

public struct PluginsView: View {

    @Environment(Store.self)
    var store: Store

    public init() {}

    public var body: some View {
        List {
            Section {
                ForEach(store.pluginManager.plugins) { state in
                    row(for: state)
                }
            } header: {
                Text("Parsers")
            } footer: {
                Text("Plugins decode advertisement and characteristic values. Built-in parsers are native; others are WebAssembly modules.")
            }
        }
        .navigationTitle("Plugins")
    }

    @ViewBuilder
    private func row(for state: PluginManager.PluginState) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(isOn: Binding(
                get: { state.isEnabled },
                set: { store.pluginManager.setEnabled($0, id: state.id) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: state.name)
                    HStack(spacing: 6) {
                        Text(verbatim: sourceLabel(state.source))
                            .font(.caption)
                            .foregroundColor(.gray)
                        if let version = state.version {
                            Text(verbatim: "v" + version)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            if let error = state.loadError {
                Text(verbatim: error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func sourceLabel(_ source: PluginManager.Source) -> String {
        switch source {
        case .native: return "Built-in"
        case .bundled: return "Bundled"
        case .imported: return "Imported"
        }
    }
}
