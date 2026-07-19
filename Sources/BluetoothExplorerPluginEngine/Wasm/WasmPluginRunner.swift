//
//  WasmPluginRunner.swift
//  BluetoothExplorerPluginEngine
//
//  Owns one plugin's WasmKit engine/store/instance, confined to a dedicated serial queue.
//  Provides a deadline-bounded async invoke; on timeout the plugin is quarantined and the
//  wedged call is abandoned on its queue (WasmKit 0.2.x has no execution interruption).
//

import Foundation
@_spi(Fuzzing) import WasmKit

/// A one-shot continuation guard so exactly one of {call completion, timeout} resumes.
private final class ResumeOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    /// Resume with `value` if not already resumed. Returns `true` if this call won the race.
    func resume(_ value: sending T) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let continuation else { return false }
        self.continuation = nil
        continuation.resume(returning: value)
        return true
    }
}

final class WasmPluginRunner: @unchecked Sendable {

    let manifest: PluginManifest

    private let moduleBytes: [UInt8]
    private let deadline: Duration
    private let warmupDeadline: Duration
    private let queue: DispatchQueue
    private let limiter: PluginResourceLimiter

    // WasmKit state — touched only on `queue`.
    private var loaded: LoadedInstance?
    private var permanentLoadError: PluginError?

    // Quarantine / failure accounting — guarded by `stateLock`, readable from any thread.
    private let stateLock = NSLock()
    private var _quarantined = false
    private var _consecutiveFailures = 0
    private var _hasLoaded = false
    private static let failureThreshold = 3
    /// Re-instantiate for hygiene after this many successful calls.
    private static let recycleAfter = 1024

    private struct LoadedInstance {
        let store: WasmKit.Store
        let instance: Instance
        let alloc: Function
        let memory: Memory
        let free: Function?
        let reset: Function?
        var callsSinceRecycle = 0
    }

    init(
        manifest: PluginManifest,
        moduleBytes: [UInt8],
        deadline: Duration = .milliseconds(50),
        warmupDeadline: Duration = .seconds(5)
    ) {
        self.manifest = manifest
        self.moduleBytes = moduleBytes
        self.deadline = deadline
        self.warmupDeadline = warmupDeadline
        self.queue = DispatchQueue(label: "bleplug.runner.\(manifest.identifier)")
        self.limiter = PluginResourceLimiter(maxMemoryBytes: manifest.maxMemoryBytes)
    }

    var isQuarantined: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _quarantined
    }

    /// Validate the module structurally without executing it. Throws on rejection.
    func validate() throws {
        let module: Module
        do {
            module = try parseWasm(bytes: moduleBytes)
        } catch {
            throw PluginError.invalidModule("\(error)")
        }
        // Only WASI preview 1 imports are permitted (Embedded Swift reactor modules need a few).
        for imported in module.imports where imported.module != WASIShim.moduleName {
            throw PluginError.disallowedImport(module: imported.module, name: imported.name)
        }
        // Marker + alloc + memory + at least the declared capability exports must be present.
        let exportNames = Set(module.exports.map(\.name))
        guard exportNames.contains(PluginABI.markerExport) else {
            throw PluginError.missingExport(PluginABI.markerExport)
        }
        guard exportNames.contains(PluginABI.allocExport) else {
            throw PluginError.missingExport(PluginABI.allocExport)
        }
        guard exportNames.contains(PluginABI.memoryExport) else {
            throw PluginError.missingExport(PluginABI.memoryExport)
        }
        for capability in manifest.declaredCapabilities {
            let export = PluginABI.parseExport(for: capability)
            guard exportNames.contains(export) else {
                throw PluginError.capabilityNotExported(export)
            }
        }
    }

    /// Decode `request`, returning the raw CBOR output bytes, or `nil` for "not mine".
    func invoke(_ request: ParseRequest) async -> Result<[UInt8]?, PluginError> {
        if isQuarantined { return .failure(.quarantined) }

        // Parsing, instantiating and `_initialize` are one-time costs that scale with module size
        // (an Embedded Swift module is ~100 KB). Bounding them with the per-call deadline would
        // quarantine healthy plugins on first use, so warm up under a separate, generous deadline
        // and reserve the tight deadline for the parse call itself.
        if hasLoaded == false {
            let warmup: Result<Void, PluginError> = await run(deadline: warmupDeadline) {
                do {
                    _ = try self.ensureLoaded()
                    return .success(())
                } catch let error as PluginError {
                    return .failure(error)
                } catch {
                    return .failure(.invalidModule("\(error)"))
                }
            }
            if case let .failure(error) = warmup {
                record(.failure(error))
                return .failure(error)
            }
            markLoaded()
        }

        let outcome: Result<[UInt8]?, PluginError> = await run(deadline: deadline) {
            do {
                return .success(try self.performCall(request))
            } catch let error as PluginError {
                return .failure(error)
            } catch {
                return .failure(.trap("\(error)"))
            }
        }
        record(outcome)
        return outcome
    }

    /// Run `body` on the plugin's serial queue, bounded by `deadline`. On timeout the plugin is
    /// quarantined and the wedged work is abandoned on the queue.
    private func run<T>(
        deadline: Duration,
        _ body: @escaping @Sendable () -> Result<T, PluginError>
    ) async -> Result<T, PluginError> {
        await withCheckedContinuation { continuation in
            let gate = ResumeOnce(continuation)
            let timeout = Task {
                try? await Task.sleep(for: deadline)
                if gate.resume(.failure(.deadlineExceeded)) {
                    self.quarantine()
                }
            }
            queue.async {
                if gate.resume(body()) {
                    timeout.cancel()
                }
            }
        }
    }

    // MARK: - Queue-confined execution

    private func ensureLoaded() throws -> LoadedInstance {
        if let permanentLoadError { throw permanentLoadError }
        if let loaded { return loaded }
        do {
            let loaded = try instantiate()
            self.loaded = loaded
            return loaded
        } catch let error as PluginError {
            permanentLoadError = error
            throw error
        } catch {
            let wrapped = PluginError.invalidModule("\(error)")
            permanentLoadError = wrapped
            throw wrapped
        }
    }

    private func instantiate() throws -> LoadedInstance {
        // Eager translation: do all of WasmKit's compilation work here, inside the generous warmup
        // deadline. With lazy mode the first call to an export pays for translating it, which on the
        // scan hot path would blow the per-call deadline and quarantine a healthy plugin.
        let engine = Engine(configuration: EngineConfiguration(compilationMode: .eager))
        let store = WasmKit.Store(engine: engine)
        store.resourceLimiter = limiter
        let module = try parseWasm(bytes: moduleBytes)
        let imports = try WASIShim.makeImports(for: module, store: store)
        let instance = try module.instantiate(store: store, imports: imports)

        // wasip1 reactor init, if present.
        if let initialize = instance.exports[function: PluginABI.initializeExport] {
            _ = try initialize([])
        }
        guard let alloc = instance.exports[function: PluginABI.allocExport] else {
            throw PluginError.missingExport(PluginABI.allocExport)
        }
        guard let memory = instance.exports[memory: PluginABI.memoryExport] else {
            throw PluginError.missingExport(PluginABI.memoryExport)
        }
        return LoadedInstance(
            store: store,
            instance: instance,
            alloc: alloc,
            memory: memory,
            free: instance.exports[function: PluginABI.freeExport],
            reset: instance.exports[function: PluginABI.resetExport]
        )
    }

    /// Executes on `queue`.
    private func performCall(_ request: ParseRequest) throws -> [UInt8]? {
        var loaded = try ensureLoaded()

        guard let parse = loaded.instance.exports[function: PluginABI.parseExport(for: request.kind)] else {
            return nil // capability not present; not an error
        }

        let envelope = PluginABI.encodeEnvelope(
            kind: request.kind,
            companyID: request.companyID,
            uuid: request.uuid,
            payload: request.payload
        )

        // Allocate input region in guest memory.
        let allocResult = try loaded.alloc([.i32(UInt32(envelope.count))])
        guard case let .i32(inputPtr)? = allocResult.first, inputPtr != 0 else {
            throw PluginError.allocationFailed
        }
        try write(envelope, at: inputPtr, memory: loaded.memory)

        // Call parse.
        let parseResult = try parse([.i32(inputPtr), .i32(UInt32(envelope.count))])
        guard case let .i64(packed)? = parseResult.first else {
            throw PluginError.trap("parse did not return i64")
        }

        // Re-read memory size after the call (it may have grown).
        let output: [UInt8]?
        if let region = PluginABI.unpackResult(packed) {
            let length = Int(region.length)
            guard length <= manifest.maxOutputBytes else {
                throw PluginError.outputTooLarge(bytes: length, limit: manifest.maxOutputBytes)
            }
            output = try read(count: length, at: region.pointer, memory: loaded.memory)
        } else {
            output = nil
        }

        // Optional cleanup.
        if let free = loaded.free {
            _ = try? free([.i32(inputPtr), .i32(UInt32(envelope.count))])
        }
        if let reset = loaded.reset {
            _ = try? reset([])
        }

        // Periodic recycle for hygiene.
        loaded.callsSinceRecycle += 1
        if loaded.callsSinceRecycle >= Self.recycleAfter {
            // Drop the instance for hygiene; the next call re-warms under the warmup deadline.
            self.loaded = nil
            clearLoaded()
        } else {
            self.loaded = loaded
        }

        return output
    }

    private func write(_ bytes: [UInt8], at pointer: UInt32, memory: Memory) throws {
        let end = Int(pointer) + bytes.count
        guard Int(pointer) >= 0, end <= memory.data.count else {
            throw PluginError.invalidResultRegion
        }
        memory.withUnsafeMutableBufferPointer(offset: UInt(pointer), count: bytes.count) { buffer in
            for index in bytes.indices { buffer[index] = bytes[index] }
        }
    }

    private func read(count: Int, at pointer: UInt32, memory: Memory) throws -> [UInt8] {
        let end = Int(pointer) + count
        guard count >= 0, Int(pointer) >= 0, end <= memory.data.count else {
            throw PluginError.invalidResultRegion
        }
        var output = [UInt8](repeating: 0, count: count)
        memory.withUnsafeMutableBufferPointer(offset: UInt(pointer), count: count) { buffer in
            for index in 0..<count { output[index] = buffer[index] }
        }
        return output
    }

    // MARK: - State

    private var hasLoaded: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _hasLoaded
    }

    private func markLoaded() {
        stateLock.lock()
        _hasLoaded = true
        stateLock.unlock()
    }

    private func clearLoaded() {
        stateLock.lock()
        _hasLoaded = false
        stateLock.unlock()
    }

    private func quarantine() {
        stateLock.lock()
        _quarantined = true
        stateLock.unlock()
    }

    private func record(_ outcome: Result<[UInt8]?, PluginError>) {
        stateLock.lock()
        defer { stateLock.unlock() }
        switch outcome {
        case .success:
            _consecutiveFailures = 0
        case .failure:
            _consecutiveFailures += 1
            if _consecutiveFailures >= Self.failureThreshold {
                _quarantined = true
            }
        }
    }
}
