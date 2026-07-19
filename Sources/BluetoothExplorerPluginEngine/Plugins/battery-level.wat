;; Reference bleplug ABI v1 plugin: GATT Battery Level (0x2A19).
;; Reads the 1-byte level from the characteristic payload and emits a CBOR result.
;;
;; Output template (41 bytes), level byte patched at index 37:
;;   A2                          map(2)
;;     00 67 "Battery"           0: summary
;;     01 81                     1: array(1)
;;       A4                        map(4)
;;         00 65 "level"           0: key
;;         01 6D "Battery Level"   1: label
;;         02 18 <level>           2: value (uint8)
;;         03 61 "%"               3: unit
;;
;; Compile with WasmKit's wat2wasm. The checked-in battery-level.wasm is the compiled artifact;
;; regenerate it if this source changes and update the manifest sha256.
(module
  (memory (export "memory") 1)
  (global $bump (mut i32) (i32.const 1024))
  (data (i32.const 256) "\a2\00\67\42\61\74\74\65\72\79\01\81\a4\00\65\6c\65\76\65\6c\01\6d\42\61\74\74\65\72\79\20\4c\65\76\65\6c\02\18\00\03\61\25")
  (func (export "bleplug_abi_1"))
  (func (export "bleplug_alloc") (param $size i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (global.get $bump))
    (global.set $bump (i32.add (global.get $bump) (local.get $size)))
    (local.get $ptr))
  (func (export "bleplug_parse_characteristic") (param $ptr i32) (param $len i32) (result i64)
    ;; payload length is at ptr+20 (u32 LE); bail with "no result" if zero
    (if (i32.eqz (i32.load (i32.add (local.get $ptr) (i32.const 20))))
      (then (return (i64.const 0))))
    ;; patch level byte: template[37] = payload[0] (payload starts at ptr+24)
    (i32.store8 (i32.const 293) (i32.load8_u (i32.add (local.get $ptr) (i32.const 24))))
    ;; return (256 << 32) | 41
    (i64.or (i64.shl (i64.const 256) (i64.const 32)) (i64.const 41)))
)
