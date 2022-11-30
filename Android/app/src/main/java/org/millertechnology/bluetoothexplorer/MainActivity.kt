package org.millertechnology.bluetoothexplorer

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Surface
import androidx.compose.ui.Modifier
import org.millertechnology.bluetoothexplorer.composable.BluetoothScannerView
import org.millertechnology.bluetoothexplorer.model.BluetoothDevice
import org.pureswift.swiftandroidsupport.app.SwiftComponentActivity
import org.millertechnology.bluetoothexplorer.ui.theme.BluetoothExplorerTheme
import java.util.ArrayList

class MainActivity : SwiftComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        android.util.Log.i("Activity", "Loading Main Activity")

        // set composable content
        setContent {
            BluetoothExplorerTheme {
                // A surface container using the 'background' color from the theme
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colors.background
                ) {
                    BluetoothScannerView(listOf())
                }
            }
        }
    }

    fun updateView(devices: ArrayList<BluetoothDevice>) {
        setContent {
            BluetoothExplorerTheme {
                // A surface container using the 'background' color from the theme
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colors.background
                ) {
                    BluetoothScannerView(devices)
                }
            }
        }
    }
}
