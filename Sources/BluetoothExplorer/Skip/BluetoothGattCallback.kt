package org.pureswift.bluetooth

import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback as AndroidGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.util.Log

/**
 * Bluetooth GATT Callback for AndroidBluetooth Swift package.
 *
 * This class is referenced by AndroidBluetooth's GattCallback
 * via the @JavaClass("org.pureswift.bluetooth.BluetoothGattCallback") annotation.
 * It extends Android's BluetoothGattCallback and provides the bridge between
 * Android's Bluetooth GATT and the Swift AndroidBluetooth package.
 */
open class BluetoothGattCallback(
    private var swiftPeer: Long = 0L
) : AndroidGattCallback() {

    fun setSwiftPeer(swiftPeer: Long) {
        this.swiftPeer = swiftPeer
    }

    fun getSwiftPeer(): Long {
        return swiftPeer
    }

    fun finalize() {
        swiftGattRelease(swiftPeer)
        swiftPeer = 0L
    }

    private external fun swiftGattRelease(swiftPeer: Long)

    companion object {
        private const val TAG = "PureSwift.GattCallback"
    }

    override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
        super.onConnectionStateChange(gatt, status, newState)
        if (swiftPeer != 0L) {
            swiftOnConnectionStateChange(swiftPeer, gatt, status, newState)
        } else {
            Log.d(TAG, "onConnectionStateChange: status=$status newState=$newState")
        }
    }
    private external fun swiftOnConnectionStateChange(swiftPeer: Long, gatt: BluetoothGatt?, status: Int, newState: Int)

    override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
        super.onServicesDiscovered(gatt, status)
        if (swiftPeer != 0L) {
            swiftOnServicesDiscovered(swiftPeer, gatt, status)
        } else {
            Log.d(TAG, "onServicesDiscovered: status=$status")
        }
    }
    private external fun swiftOnServicesDiscovered(swiftPeer: Long, gatt: BluetoothGatt?, status: Int)

    @Deprecated("Deprecated in Java")
    override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        @Suppress("DEPRECATION")
        super.onCharacteristicChanged(gatt, characteristic)
        if (swiftPeer != 0L) {
            swiftOnCharacteristicChanged(swiftPeer, gatt, characteristic)
        } else {
            Log.d(TAG, "onCharacteristicChanged: ${characteristic.uuid}")
        }
    }
    private external fun swiftOnCharacteristicChanged(swiftPeer: Long, gatt: BluetoothGatt?, characteristic: BluetoothGattCharacteristic?)

    @Deprecated("Deprecated in Java")
    override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
        @Suppress("DEPRECATION")
        super.onCharacteristicRead(gatt, characteristic, status)
        if (swiftPeer != 0L) {
            swiftOnCharacteristicRead(swiftPeer, gatt, characteristic, status)
        } else {
            Log.d(TAG, "onCharacteristicRead: ${characteristic.uuid} status=$status")
        }
    }
    private external fun swiftOnCharacteristicRead(swiftPeer: Long, gatt: BluetoothGatt?, characteristic: BluetoothGattCharacteristic?, status: Int)

    override fun onCharacteristicWrite(gatt: BluetoothGatt?, characteristic: BluetoothGattCharacteristic?, status: Int) {
        super.onCharacteristicWrite(gatt, characteristic, status)
        if (swiftPeer != 0L) {
            swiftOnCharacteristicWrite(swiftPeer, gatt, characteristic, status)
        } else {
            Log.d(TAG, "onCharacteristicWrite: ${characteristic?.uuid} status=$status")
        }
    }
    private external fun swiftOnCharacteristicWrite(swiftPeer: Long, gatt: BluetoothGatt?, characteristic: BluetoothGattCharacteristic?, status: Int)

    @Deprecated("Deprecated in Java")
    override fun onDescriptorRead(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
        @Suppress("DEPRECATION")
        super.onDescriptorRead(gatt, descriptor, status)
        if (swiftPeer != 0L) {
            swiftOnDescriptorRead(swiftPeer, gatt, descriptor, status)
        } else {
            Log.d(TAG, "onDescriptorRead: ${descriptor.uuid} status=$status")
        }
    }
    private external fun swiftOnDescriptorRead(swiftPeer: Long, gatt: BluetoothGatt?, descriptor: BluetoothGattDescriptor?, status: Int)

    override fun onDescriptorWrite(gatt: BluetoothGatt?, descriptor: BluetoothGattDescriptor?, status: Int) {
        super.onDescriptorWrite(gatt, descriptor, status)
        if (swiftPeer != 0L) {
            swiftOnDescriptorWrite(swiftPeer, gatt, descriptor, status)
        } else {
            Log.d(TAG, "onDescriptorWrite: ${descriptor?.uuid} status=$status")
        }
    }
    private external fun swiftOnDescriptorWrite(swiftPeer: Long, gatt: BluetoothGatt?, descriptor: BluetoothGattDescriptor?, status: Int)

    override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
        super.onMtuChanged(gatt, mtu, status)
        if (swiftPeer != 0L) {
            swiftOnMtuChanged(swiftPeer, gatt, mtu, status)
        } else {
            Log.d(TAG, "onMtuChanged: mtu=$mtu status=$status")
        }
    }
    private external fun swiftOnMtuChanged(swiftPeer: Long, gatt: BluetoothGatt?, mtu: Int, status: Int)

    override fun onPhyRead(gatt: BluetoothGatt?, txPhy: Int, rxPhy: Int, status: Int) {
        super.onPhyRead(gatt, txPhy, rxPhy, status)
        if (swiftPeer != 0L) {
            swiftOnPhyRead(swiftPeer, gatt, txPhy, rxPhy, status)
        } else {
            Log.d(TAG, "onPhyRead: txPhy=$txPhy rxPhy=$rxPhy status=$status")
        }
    }
    private external fun swiftOnPhyRead(swiftPeer: Long, gatt: BluetoothGatt?, txPhy: Int, rxPhy: Int, status: Int)

    override fun onPhyUpdate(gatt: BluetoothGatt?, txPhy: Int, rxPhy: Int, status: Int) {
        super.onPhyUpdate(gatt, txPhy, rxPhy, status)
        if (swiftPeer != 0L) {
            swiftOnPhyUpdate(swiftPeer, gatt, txPhy, rxPhy, status)
        } else {
            Log.d(TAG, "onPhyUpdate: txPhy=$txPhy rxPhy=$rxPhy status=$status")
        }
    }
    private external fun swiftOnPhyUpdate(swiftPeer: Long, gatt: BluetoothGatt?, txPhy: Int, rxPhy: Int, status: Int)

    override fun onReadRemoteRssi(gatt: BluetoothGatt?, rssi: Int, status: Int) {
        super.onReadRemoteRssi(gatt, rssi, status)
        if (swiftPeer != 0L) {
            swiftOnReadRemoteRssi(swiftPeer, gatt, rssi, status)
        } else {
            Log.d(TAG, "onReadRemoteRssi: rssi=$rssi status=$status")
        }
    }
    private external fun swiftOnReadRemoteRssi(swiftPeer: Long, gatt: BluetoothGatt?, rssi: Int, status: Int)

    override fun onReliableWriteCompleted(gatt: BluetoothGatt?, status: Int) {
        super.onReliableWriteCompleted(gatt, status)
        if (swiftPeer != 0L) {
            swiftOnReliableWriteCompleted(swiftPeer, gatt, status)
        } else {
            Log.d(TAG, "onReliableWriteCompleted: status=$status")
        }
    }
    private external fun swiftOnReliableWriteCompleted(swiftPeer: Long, gatt: BluetoothGatt?, status: Int)
}
