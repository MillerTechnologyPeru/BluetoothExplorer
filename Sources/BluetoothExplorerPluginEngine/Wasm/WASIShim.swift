//
//  WASIShim.swift
//  BluetoothExplorerPluginEngine
//
//  A deliberately tiny WASI (preview 1) host surface. Embedded Swift compiles plugins as wasip1
//  reactor modules that import a handful of `wasi_snapshot_preview1` functions (at minimum
//  `random_get`). We satisfy exactly the functions a module declares — providing real randomness
//  and stubbing everything else to "success" — rather than linking a full WASI implementation.
//  This keeps the engine free of filesystem/socket capabilities: plugins get randomness and nothing
//  that touches the host.
//

import Foundation
@_spi(Fuzzing) import WasmKit

enum WASIShim {

    /// The only import module a plugin may reference.
    static let moduleName = "wasi_snapshot_preview1"

    /// Build an `Imports` satisfying every `wasi_snapshot_preview1` function the module declares.
    /// - Throws: `PluginError.disallowedImport` if the module imports anything outside WASI.
    static func makeImports(for module: Module, store: Store) throws -> Imports {
        var imports = Imports()
        for entry in module.imports {
            guard entry.module == moduleName else {
                throw PluginError.disallowedImport(module: entry.module, name: entry.name)
            }
            guard case let .function(typeIndex) = entry.descriptor else {
                // WASI preview 1 imports are all functions; anything else is unexpected.
                throw PluginError.disallowedImport(module: entry.module, name: entry.name)
            }
            let type = module.types[Int(typeIndex)]
            let name = entry.name
            let function = Function(store: store, type: type) { caller, arguments in
                try handle(name: name, caller: caller, arguments: arguments, results: type.results)
            }
            imports.define(module: moduleName, name: name, function)
        }
        return imports
    }

    private static func handle(
        name: String,
        caller: borrowing Caller,
        arguments: [Value],
        results: [ValueType]
    ) throws -> [Value] {
        switch name {
        case "random_get":
            fillRandom(caller: caller, arguments: arguments)
            return [.i32(0)] // __WASI_ERRNO_SUCCESS
        default:
            // Stub: report success and return zero-valued results. Plugins must not depend on any
            // host effect beyond randomness.
            return results.map(zeroValue)
        }
    }

    /// `random_get(buf: i32, buf_len: i32) -> errno`: fill guest memory with random bytes.
    private static func fillRandom(caller: borrowing Caller, arguments: [Value]) {
        guard arguments.count == 2,
              case let .i32(pointer) = arguments[0],
              case let .i32(length) = arguments[1],
              let instance = caller.instance,
              let memory = instance.exports[memory: PluginABI.memoryExport],
              length > 0
        else { return }

        var generator = SystemRandomNumberGenerator()
        let count = Int(length)
        memory.withUnsafeMutableBufferPointer(offset: UInt(pointer), count: count) { buffer in
            for index in 0..<count {
                buffer[index] = UInt8.random(in: UInt8.min...UInt8.max, using: &generator)
            }
        }
    }

    private static func zeroValue(for type: ValueType) -> Value {
        switch type {
        case .i32: return .i32(0)
        case .i64: return .i64(0)
        case .f32: return .f32(0)
        case .f64: return .f64(0)
        default: return .i32(0)
        }
    }
}
