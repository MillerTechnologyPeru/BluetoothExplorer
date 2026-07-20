//
//  Plugin.swift
//  IBeacon
//
//  Decodes Apple iBeacon advertisements from manufacturer-specific data.
//
//  Payload layout (after the company identifier, which the host strips into the envelope header):
//    [0]      type   = 0x02
//    [1]      length = 0x15 (21)
//    [2..17]  proximity UUID, big-endian
//    [18..19] major, big-endian
//    [20..21] minor, big-endian
//    [22]     measured power at 1m, signed
//
//  Field keys and labels intentionally match NativeIBeaconParser so the two can be diffed.
//

import BLEPluginSDK

private let appleCompanyIdentifier: UInt16 = 0x004C
private let iBeaconType: UInt8 = 0x02
private let iBeaconLength: UInt8 = 0x15

func parseManufacturerData(_ input: ParseInput) -> Fields? {
    guard input.companyIdentifier == appleCompanyIdentifier else { return nil }

    var payload = input.payload
    // Apple ships several manufacturer-data formats under this company id; only 0x02/0x15 is
    // an iBeacon. Anything else is declined so other parsers (or the raw view) can handle it.
    guard payload.remaining == 23,
          payload.readUInt8() == iBeaconType,
          payload.readUInt8() == iBeaconLength,
          let uuid = payload.readUUID(),
          let major = payload.readUInt16BigEndian(),
          let minor = payload.readUInt16BigEndian(),
          let measuredPower = payload.readInt8()
    else { return nil }

    var fields = Fields(summary: "iBeacon")
    fields.uuid("uuid", label: "Proximity UUID", uuid)
    fields.uint("major", label: "Major", UInt64(major))
    fields.uint("minor", label: "Minor", UInt64(minor))
    fields.int("tx_power", label: "Measured Power", Int64(measuredPower), unit: "dBm")
    return fields
}
