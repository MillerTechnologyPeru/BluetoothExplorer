package org.millertechnology.bluetoothexplorer

import org.pureswift.swiftandroidsupport.app.SwiftApplication

class Application: SwiftApplication() {

    companion object {

        init {
            loadNativeLibrary()
        }

        private fun loadNativeLibrary() {
            System.loadLibrary("icuuc")
            System.loadLibrary("icui18n")
            System.loadLibrary("Foundation")
            System.loadLibrary("BluetoothExplorer")
        }
    }
}