//
//  Logging.swift
//  BluetoothExplorer
//
//  A minimal logger so the app does not depend on a cross-platform logging framework.
//  Apple platforms use `os.Logger`; Android falls back to printing, which AndroidSwiftUI's
//  runtime surfaces through logcat.
//

#if canImport(os)
import os

typealias AppLogger = os.Logger
#else
/// Stand-in for `os.Logger` on platforms without the unified logging system.
struct AppLogger {

    let subsystem: String
    let category: String

    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    func debug(_ message: String) { emit("DEBUG", message) }
    func info(_ message: String) { emit("INFO", message) }
    func notice(_ message: String) { emit("NOTICE", message) }
    func warning(_ message: String) { emit("WARNING", message) }
    func error(_ message: String) { emit("ERROR", message) }

    private func emit(_ level: String, _ message: String) {
        print("[\(level)] \(subsystem)/\(category): \(message)")
    }
}
#endif
