package org.millertechnology.bluetoothexplorer.composable

import android.os.Build
import androidx.annotation.RequiresApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import org.millertechnology.bluetoothexplorer.R
import org.millertechnology.bluetoothexplorer.model.BluetoothDevice
import org.millertechnology.bluetoothexplorer.ui.theme.BluetoothExplorerTheme
import java.time.Instant
import java.util.*

@Composable
fun BluetoothScannerView(devices: List<BluetoothDevice>) {
    if (devices.isEmpty()) {
        Column {
            Text(text = "No Bluetooth devices")
        }
    } else {
        LazyColumn {
            devices.map {
                item(key = it.id) {
                    BluetoothScanResultView(it)
                }
            }
        }
    }
}

@Composable
fun BluetoothScanResultView(scanData: BluetoothDevice) {
    Row(modifier = Modifier.padding(all = 8.dp)) {
        Image(painter = painterResource(id = R.drawable.ic_bluetooth), contentDescription = "Bluetooth")
        Column(modifier = Modifier.padding(bottom = 4.dp)) {
            Text("${scanData.address}")
            if (scanData.name != null) {
                Text("${scanData.name}")
            }
            if (scanData.company != null) {
                Text("${scanData.company}")
            }
        }
    }
}

@RequiresApi(Build.VERSION_CODES.O)
@Preview(showBackground = true)
@Composable
fun DefaultPreview() {
    BluetoothExplorerTheme {
        BluetoothScannerView(
            listOf(
                BluetoothDevice("1", Date.from(Instant.now()), "00:01:02:03:AA:BB", "iBeacon", "Apple"),
                BluetoothDevice("2", Date.from(Instant.now()),"00:02:02:03:AA:BB", "CLI-W200", "Savant Systems LLC"),
                BluetoothDevice("3", Date.from(Instant.now()),"00:03:02:03:AA:BB")
            )
        )
    }
}