//
//  PluginsView.swift
//  BluetoothExplorerUI
//
//  Manages parser plugins: enable/disable, import from a file, delete, and surface load errors.
//  Bundled plugins are copied into the app's Documents directory on first launch, so everything
//  listed here lives in one place the user can inspect.
//

#if canImport(SwiftUI)
import SwiftUI
#else
import AndroidSwiftUI
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
import BluetoothExplorerModel

public struct PluginsView: View {

    @Environment(Store.self)
    var store: Store

    // Not `private`: Skip's bridging requires @State properties to be at least internal.
    @State var isImporting = false
    @State var importError: String?

    public init() {}

    public var body: some View {
        List {
            Section {
                ForEach(store.pluginManager.plugins) { state in
                    row(for: state)
                }
                .onDelete { offsets in
                    delete(at: offsets)
                }
            } header: {
                Text("Parsers")
            } footer: {
                Text("Plugins decode advertisement and characteristic values. Built-in parsers are native; others are WebAssembly modules stored in the app's Documents folder.")
            }

            if let error = importError {
                Section {
                    Text(verbatim: error)
                        .font(.caption)
                        .foregroundColor(.red)
                } header: {
                    Text("Import Failed")
                }
            }
        }
        .navigationTitle("Plugins")
        #if !os(Android)
        .toolbar {
            Button {
                importError = nil
                isImporting = true
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        #endif
    }

    // MARK: Actions

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            switch store.pluginManager.importPlugin(manifestURL: url) {
            case .success:
                importError = nil
            case let .failure(error):
                importError = error.message
            }
        case let .failure(error):
            importError = "\(error)"
        }
    }

    private func delete(at offsets: IndexSet) {
        let plugins = store.pluginManager.plugins
        for index in offsets where index < plugins.count {
            let state = plugins[index]
            // Native parsers are compiled in; there is nothing on disk to remove.
            guard state.source != .native else { continue }
            store.pluginManager.removePlugin(id: state.id)
        }
    }

    // MARK: Rows

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
