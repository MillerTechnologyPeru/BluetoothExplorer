package org.millertechnology.bluetoothexplorer

import android.bluetooth.BluetoothDevice
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Surface
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import org.millertechnology.bluetoothexplorer.ui.theme.BluetoothExplorerTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // set composable content
        setContent {
            BluetoothExplorerTheme {
                // A surface container using the 'background' color from the theme
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colors.background
                ) {
                    Greeting("Android")
                }
            }
        }
    }
}

@Composable
fun Greeting(name: String) {
    Text(text = "Hello $name!")
}

@Composable
fun BluetoothScannerView(items: List<ScanData>) {
    LazyColumn {
        items.map {
            item(key = it.id) {
                BluetoothScanResultView(it)
            }
        }
    }
}

data class ScanData(val id: String, val address: String, val name: String? = null, val companyName: String? = null)

@Composable
fun BluetoothScanResultView(scanData: ScanData) {
    Row(modifier = Modifier.padding(all = 8.dp)) {
        Image(painter = painterResource(id = R.drawable.ic_bluetooth), contentDescription = "Bluetooth")
        Column(modifier = Modifier.padding(bottom = 4.dp)) {
            Text("${scanData.address}")
            if (scanData.name != null) {
                Text("${scanData.name}")
            }
            if (scanData.companyName != null) {
                Text("${scanData.companyName}")
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun DefaultPreview() {
    BluetoothExplorerTheme {
        BluetoothScannerView(
            listOf(
                ScanData("1", "00:01:02:03:AA:BB", "iBeacon", "Apple"),
                ScanData("2", "00:02:02:03:AA:BB", "CLI-W200", "Savant Systems LLC"),
                ScanData("3", "00:02:02:03:AA:BB")
            )
        )
    }
}