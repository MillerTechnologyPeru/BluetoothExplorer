//
//  Shortcuts.swift
//  
//
//  Created by Alsey Coleman Miller on 11/20/22.
//

#if canImport(AppIntents)
import AppIntents

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
struct AppShortcuts: AppShortcutsProvider {
    
    /// The background color of the tile that Shortcuts displays for each of the app's App Shortcuts.
    static var shortcutTileColor: ShortcutTileColor {
        .navy
    }
    
    static var appShortcuts: [AppShortcut] {
        
        AppShortcut(
            intent: ScanIntent(),
            phrases: [
                "Scan for nearby Bluetooth devices with \(.applicationName)",
            ],
            systemImageName: "arrow.clockwise"
        )
    }
}
#endif
