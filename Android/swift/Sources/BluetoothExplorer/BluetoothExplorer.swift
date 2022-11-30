import Foundation
import Android
import AndroidBluetooth
import Bluetooth
import GATT
import JavaCoder

final class BluetoothExplorerApp: SwiftApplication {
    
    let launchDate = Date()
    
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        return formatter
    }()
    
    class override var runtimeConfiguration: RuntimeConfiguration {
        var configuration = RuntimeConfiguration.default
        configuration.componentActivity = MainActivity.self
        return configuration
    }
    
    override func onCreate() {
        super.onCreate()
        
        didLaunch()
    }
    
    func didLaunch() {
        NSLog("Launching BluetoothExplorer Android app \(Self.formatter.string(from: launchDate))")
        
        // register coder
        JavaCoderConfig.RegisterBasicJavaTypes()
    }
}

@_silgen_name("SwiftAndroidMainApplication")
public func SwiftAndroidMainApplication() -> SwiftApplication.Type {
    NSLog("\(#function)")
    return BluetoothExplorerApp.self
}

/*
extension BluetoothExplorerApp {
    
    /// Checks if permissions are needed.
    @discardableResult
    func enableBluetooth(hostController: Android.Bluetooth.Adapter) {
        
        guard hostController.isEnabled() == false
            else { return requestLocationPermissions() }
        
        let enableBluetoothIntent = Android.Content.Intent(action: Android.Bluetooth.Adapter.Action.requestEnable.rawValue)
        
        log("\(type(of: self)) \(#function) enable Bluetooth")
        
        return false
    }
    
    @discardableResult
    func requestLocationPermissions() -> Bool {
        
        let activity = UIApplication.shared.androidActivity
        
        if Android.OS.Build.Version.Sdk.sdkInt.rawValue >= Android.OS.Build.VersionCodes.M,
            activity.checkSelfPermission(permission: Android.ManifestPermission.accessCoarseLocation.rawValue) != Android.Content.PM.PackageManager.Permission.granted.rawValue {
            
            log("\(type(of: self)) \(#function) request permission")
            
            let permissions = [Android.ManifestPermission.accessCoarseLocation.rawValue, Android.ManifestPermission.writeExternalStorage.rawValue]
            
            activity.requestPermissions(permissions: permissions, requestCode: AndroidPermissionRequest.gpsAndWriteStorage)
            
            return false
            
        } else {
            
            log("\(type(of: self)) \(#function) dont need to request permissions")
            
            return true
        }
    }
}
*/
