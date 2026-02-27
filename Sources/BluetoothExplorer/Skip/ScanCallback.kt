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
open class ScanCallback(
    private var swiftPeer: Long = 0L
) : AndroidScanCallback() {

    fun setSwiftPeer(swiftPeer: Long) {
        this.swiftPeer = swiftPeer
    }
    
    fun getSwiftPeer(): Long {
        return swiftPeer
    }

    fun finalize() {
        swiftRelease(swiftPeer)
        swiftPeer = 0L
    }

    private external fun swiftRelease(swiftPeer: Long)

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
        swiftOnScanResult(swiftPeer, callbackType, result)
    }

    external fun swiftOnScanResult(
        swiftPeer: Long,
        callbackType: Int,
        result: ScanResult?
    )

    /**
     * Callback when batch results are delivered.
     *
     * @param results List of scan results that are previously scanned
     */
    override fun onBatchScanResults(results: MutableList<ScanResult>?) {
        super.onBatchScanResults(results)
        if (swiftPeer != 0L) {
            swiftOnBatchScanResults(swiftPeer, results)
        } else {
            Log.d(TAG, "onBatchScanResults: ${results?.size ?: 0} results")
        }
    }
    private external fun swiftOnBatchScanResults(
        swiftPeer: Long,
        results: MutableList<ScanResult>?
    )

    /**
     * Callback when scan could not be started.
     *
     * @param errorCode Error code (one of SCAN_FAILED_*)
     */
    override fun onScanFailed(errorCode: Int) {
        super.onScanFailed(errorCode)
        if (swiftPeer != 0L) {
            swiftOnScanFailed(swiftPeer, errorCode)
        } else {
            Log.e(TAG, "onScanFailed: errorCode=$errorCode")
        }
    }
    private external fun swiftOnScanFailed(swiftPeer: Long, errorCode: Int)
}
