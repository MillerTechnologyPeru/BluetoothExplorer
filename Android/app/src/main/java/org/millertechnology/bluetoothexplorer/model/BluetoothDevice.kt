package org.millertechnology.bluetoothexplorer.model

import java.util.*

data class BluetoothDevice(
    val id: String,
    val date: Date,
    val address: String,
    val name: String? = null,
    val company: String? = null
)