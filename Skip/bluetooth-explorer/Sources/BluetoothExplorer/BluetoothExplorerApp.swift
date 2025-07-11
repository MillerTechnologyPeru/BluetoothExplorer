import Foundation
import OSLog
import SwiftUI
import Bluetooth
import GATT
import BluetoothExplorerModel

/// A logger for the BluetoothExplorer module.
let logger: Logger = Logger(subsystem: "org.pureswift.bluetoothexplorer", category: "BluetoothExplorer")

/// The shared top-level view for the app, loaded from the platform-specific App delegates below.
///
/// The default implementation merely loads the `ContentView` for the app and logs a message.
public struct BluetoothExplorerRootView : View {
    
    @State var store = Store()
    
    public init() {
    }

    public var body: some View {
        CentralList()
            .environment(store)
            .task {
                logger.info("Skip app logs are viewable in the Xcode console for iOS; Android logs can be viewed in Studio or using adb logcat")
            }
            
    }
}

/// Global application delegate functions.
///
/// These functions can update a shared observable object to communicate app state changes to interested views.
public final class BluetoothExplorerAppDelegate : Sendable {
    public static let shared = BluetoothExplorerAppDelegate()

    private init() {
    }

    public func onInit() {
        logger.debug("onInit")
    }

    public func onLaunch() {
        logger.debug("onLaunch")
    }

    public func onResume() {
        logger.debug("onResume")
    }

    public func onPause() {
        logger.debug("onPause")
    }

    public func onStop() {
        logger.debug("onStop")
    }

    public func onDestroy() {
        logger.debug("onDestroy")
    }

    public func onLowMemory() {
        logger.debug("onLowMemory")
    }
}
