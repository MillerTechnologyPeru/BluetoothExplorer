//
//  MockCentralConnectionTests.swift
//  BluetoothExplorerModelTests
//
//  Covers the connection-level parts of the Central API — MTU, RSSI and `disconnectAll` — which the
//  app reads once a peripheral is connected.
//
//  These went untested for a long time because nothing in the app called them, and a latent
//  force-unwrap of an out-of-range `RSSI` in the mock crashed the moment the UI first did. The RSSI
//  range assertion below is the regression test for that.
//

import Foundation
import Testing
import Bluetooth
import GATT
@testable import BluetoothExplorerModel

#if DEBUG

@MainActor
@Suite("Mock central connection info")
struct MockCentralConnectionTests {

    private func connectedPeripheral() async throws -> (MockCentral, Peripheral) {
        let central = MockCentral()
        let peripheral = try #require(await central.peripherals.keys.sorted(by: { $0.id < $1.id }).first)
        try await central.connect(to: peripheral)
        return (central, peripheral)
    }

    @Test("RSSI is within the range RSSI accepts")
    func rssiIsInRange() async throws {
        let (central, peripheral) = try await connectedPeripheral()
        // `RSSI.init?(rawValue:)` only accepts -127...20, so a mock returning anything else used to
        // trap on a force unwrap before it could ever be returned.
        let rssi = try await central.rssi(for: peripheral)
        #expect(rssi.rawValue >= -127)
        #expect(rssi.rawValue <= 20)
    }

    @Test("Reading RSSI while disconnected throws instead of trapping")
    func rssiRequiresConnection() async throws {
        let central = MockCentral()
        let peripheral = try #require(await central.peripherals.keys.sorted(by: { $0.id < $1.id }).first)
        await #expect(throws: (any Error).self) {
            _ = try await central.rssi(for: peripheral)
        }
    }

    @Test("MTU is readable once connected and rejected once not")
    func maximumTransmissionUnit() async throws {
        let (central, peripheral) = try await connectedPeripheral()
        let mtu = try await central.maximumTransmissionUnit(for: peripheral)
        #expect(mtu.rawValue >= MaximumTransmissionUnit.default.rawValue)

        await central.disconnect(peripheral)
        await #expect(throws: (any Error).self) {
            _ = try await central.maximumTransmissionUnit(for: peripheral)
        }
    }

    @Test("disconnectAll drops every connection")
    func disconnectAll() async throws {
        let central = MockCentral()
        let peripherals = await central.peripherals.keys.sorted(by: { $0.id < $1.id })
        #expect(peripherals.isEmpty == false)
        for peripheral in peripherals {
            try await central.connect(to: peripheral)
        }
        #expect(await central.peripherals.values.contains(true))

        await central.disconnectAll()
        #expect(await central.peripherals.values.allSatisfy { $0 == false })
    }
}

#endif
