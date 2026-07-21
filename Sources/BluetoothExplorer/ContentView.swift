#if canImport(SwiftUI)
import SwiftUI
#else
import AndroidSwiftUI
#endif
import BluetoothExplorerUI

enum ContentTab: String, Hashable {
    case devices, plugins, settings
}

struct ContentView: View {
    @AppStorage("tab") var tab = ContentTab.devices
    @AppStorage("appearance") var appearance = ""

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                CentralList()
            }
            .tabItem { Label("Devices", systemImage: "dot.radiowaves.left.and.right") }
            .tag(ContentTab.devices)

            NavigationStack {
                PluginsView()
            }
            .tabItem { Label("Plugins", systemImage: "puzzlepiece.extension.fill") }
            .tag(ContentTab.plugins)

            NavigationStack {
                SettingsView(appearance: $appearance)
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(ContentTab.settings)
        }
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
    }
}

struct SettingsView: View {
    @Binding var appearance: String

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(buildNumber))")
            }
        }
    }
}
