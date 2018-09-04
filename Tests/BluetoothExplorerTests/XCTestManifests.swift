import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BluetoothExplorerTests.allTests),
    ]
}
#endif