//
//  File.swift
//  
//
//  Created by Alsey Coleman Miller on 11/30/22.
//

import Foundation
import Android
import AndroidBluetooth
import Bluetooth
import GATT
import JavaCoder
import JNI
import java_swift
import java_lang
import CJavaVM

@available(macOS 13.0, *)
@MainActor
final class MainActivity: SwiftComponentActivity {
    
    var foundDevices = [String: BluetoothDevice]()
    
    override nonisolated func onCreate(savedInstanceState: Android.OS.Bundle?) {
        super.onCreate(savedInstanceState: savedInstanceState)
        
        drainMainQueue()
        
        // setup activity
        didLoad()
    }
    
    private nonisolated func drainMainQueue() {
        // drain main queue
        Task { [weak self] in
            while let self = self {
                try? await Task.sleep(for: .milliseconds(100))
                self.runOnMainThread {
                    RunLoop.main.run(until: Date() + 0.01)
                }
            }
        }
    }
    
    private nonisolated func didLoad() {
        
        // TODO: Request Bluetooth permissions
        
        // Start scan
        Task {
            do {
                try await scan()
            }
            catch {
                NSLog("Error: \(error)")
            }
        }
        
        
    }
    
    private func updateView() {
        
        let devices = self.foundDevices.values.sorted(by: { $0.id < $1.id })
        
        var __locals = [jobject]()
        var __args = [jvalue]( repeating: jvalue(), count: 1 )
        do {
            __args[0] = try JavaEncoder.bluetoothExplorer.encode(devices).value(locals: &__locals)
        }
        catch {
            NSLog("Unable to encode Java Object. \(error)")
            return
        }
        
        JNIMethod.CallVoidMethod(
            object: javaObject,
            methodName: "updateView",
            methodSig: "(Ljava/util/ArrayList;)V",
            methodCache: &JNICache.MethodID.updateView,
            args: &__args,
            locals: &__locals
        )
    }
    
    private func scan() async throws {
        
        // setup central
        guard let hostController = Android.Bluetooth.Adapter.default, hostController.isEnabled() else {
            throw AndroidCentralError.bluetoothDisabled
        }
        let central = AndroidCentral(
            hostController: hostController,
            context: .init(casting: self)!
        )
        central.log = { NSLog("Central: \($0)") }
        
        // start scanning
        let stream = try await central.scan()
        for try await scanData in stream {
            NSLog("Found \(scanData.peripheral)")
            if let localName = scanData.advertisementData.localName {
                NSLog("\(localName)")
            }
            if let manufacturerData = scanData.advertisementData.manufacturerData {
                NSLog("\(manufacturerData.companyIdentifier)")
            }
            let device = BluetoothDevice(
                id: scanData.peripheral.description,
                date: scanData.date,
                address: scanData.peripheral.id.description,
                name: scanData.advertisementData.localName,
                company: scanData.advertisementData.manufacturerData?.companyIdentifier.name
            )
            // update UI
            self.foundDevices[device.id] = device
            self.updateView()
        }
    }
}

private extension MainActivity {
        
    struct JNICache {
        
        struct MethodID {
            
            static var updateView: jmethodID?
        }
    }
}
