package com.millertech.bluetoothexplorer

import org.pureswift.swiftandroidsupport.app.SwiftApplication

class Application: SwiftApplication() {

    companion object {

        init {
            System.loadLibrary("BluetoothExplorerAndroid")
        }
    }
}