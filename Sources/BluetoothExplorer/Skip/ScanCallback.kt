package org.pureswift.bluetooth.le

import android.bluetooth.le.ScanCallback as AndroidScanCallback
import android.bluetooth.le.ScanResult
import android.util.Log

/**
 * Bluetooth LE Scan Callback for AndroidBluetooth Swift package.
 *
 * This class is referenced by AndroidBluetooth's LowEnergyScanCallback
 * via the @JavaClass("org.pureswift.bluetooth.le.ScanCallback") annotation.
 * It extends Android's ScanCallback and provides the bridge between
 * Android's Bluetooth LE scanning and the Swift AndroidBluetooth package.
 */
open class ScanCallback : AndroidScanCallback() {

    companion object {
        private const val TAG = "PureSwift.ScanCallback"
    }

    /**
     * Callback when a BLE advertisement has been found.
     *
     * @param callbackType Determines how this callback was triggered
     * @param result A Bluetooth LE scan result
     */
    override fun onScanResult(callbackType: Int, result: ScanResult?) {
        super.onScanResult(callbackType, result)
        // The Swift AndroidBluetooth.LowEnergyScanCallback overrides this method
        // via @JavaImplementation, so this is just the base implementation
        Log.d(TAG, "onScanResult: callbackType=$callbackType, result=$result")
    }

    /**
     * Callback when batch results are delivered.
     *
     * @param results List of scan results that are previously scanned
     */
    override fun onBatchScanResults(results: MutableList<ScanResult>?) {
        super.onBatchScanResults(results)
        // The Swift AndroidBluetooth.LowEnergyScanCallback overrides this method
        // via @JavaImplementation, so this is just the base implementation
        Log.d(TAG, "onBatchScanResults: ${results?.size ?: 0} results")
    }

    /**
     * Callback when scan could not be started.
     *
     * @param errorCode Error code (one of SCAN_FAILED_*)
     */
    override fun onScanFailed(errorCode: Int) {
        super.onScanFailed(errorCode)
        // The Swift AndroidBluetooth.LowEnergyScanCallback overrides this method
        // via @JavaImplementation, so this is just the base implementation
        Log.e(TAG, "onScanFailed: errorCode=$errorCode")
    }
}
