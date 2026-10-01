# Rustdoc to Nim models

![AI Generated](https://img.shields.io/badge/AI%20Generated-C99700?logo=openai&logoColor=white)

These two Nim tools convert the local boxcars Rustdoc snapshot into model
declarations. They use only Nim's standard library and do not translate Rust
methods, network decoding logic, serde implementations, or wire encodings.

Run from the repository root (Nim 2.2.6 or newer):

```powershell
nim c -r --out:bin/debug/rustupdoc.exe tools/rustupdoc.nim local/nimboxcarsTools/boxcars.json local/network.forms.json
nim c -r --out:bin/debug/updoc2.exe tools/updoc2.nim local/network.forms.json local/network_models.nim
nim check local/network_models.nim
```

Both executables accept `--help`. Paths are command-line arguments, not tied to
the author's machine. Output parent directories must already exist. The generated
module is a standalone reference under `local/`; it does not replace the library's
existing models. `local/` is ignored by Git.

## Stage 1: rustupdoc

```text
rustupdoc <rustdoc.json> <forms.json> [module-prefix=boxcars::network]
```

The input is produced by `cargo +nightly rustdoc -- --output-format json`.
Use `--document-private-items` as well if crate-private declarations such as
`AttributeTag` are absent from a regenerated snapshot. The supplied snapshot uses
Rustdoc format version 57 and contains that enum.

Selection includes public structs/enums under the module prefix, plus
`AttributeTag` when present. Private decoder implementation structs are excluded.
References outside the selected declarations must be supported standard library
types; otherwise stage 2 reports an unresolved type. Narrowing the prefix may
therefore exclude required dependencies. `NetworkFrames`, declared outside
`boxcars::network`, is not selected by the default prefix.

The output has `schemaVersion: 1`, source `rustdocFormatVersion`, `module`, and a
sorted `types` array. Each declaration preserves its Rustdoc ID, qualified path,
name, kind, and ordered fields or variants. Field types are recursive records
with `kind` values `primitive`, `path`, `array`, or `tuple`. A path retains its ID,
fully qualified name, and type arguments even when the external declaration is
not in Rustdoc's index. Numeric and string item IDs are both accepted.

Unsupported Rust constructs and stripped fields are errors, not null placeholders.
The schema replaces the old incomplete `forms.json` format; regenerate that file
before running stage 2. The supplied snapshot generates 48 declarations.

## Stage 2: updoc2

```text
updoc2 <forms.json> <models.nim>
```

| Rust | Nim |
|---|---|
| Numeric primitives / bool | Corresponding Nim width / bool |
| `String` | `string` |
| `Option<T>` | `Option[T]` |
| `Vec<T>` | `seq[T]` |
| `Box<T>` | `ref T` |
| `[T; N]` | `array[N, T]` (literal length) |
| Tuple | Named Nim tuple with `field0`, `field1`, etc. |
| Single-field tuple struct | `distinct T` |
| Other structs | Exported objects; snake_case fields become camelCase |
| Unit-only enum | Pure enum |
| Enum with payloads | Pure `NameKind` enum and `Name` variant object |

Payload fields are named after the variant with a `Value` suffix. For example,
`Attribute::FlaggedByte(bool, u8)` becomes `Attribute(kind:
AttributeKind.FlaggedByte, flaggedByteValue: (true, 1'u8))`. Multiple payload
values use named tuples. Unit variants have no payload. `AttributeKind` describes
actual payloads and is intentionally separate from Rust's decoder `AttributeTag`.

Declarations share one `type` block and are ordered by dependency. This avoids
incorrect shallow copies of managed payloads with Nim 2.2's forward references.
Recursive model dependencies are rejected. Identifiers
are escaped and collisions are rejected. `options` is re-exported for callers.
This preserves model values and optionality, not Rust ABI, ownership, or serde
serialization behavior. No missing newer upstream fields are invented.

## Verification

The regression suite uses a self-contained synthetic Rustdoc fixture and compiles
and executes a consumer of the generated models:

```powershell
nim c -r --out:bin/debug/test_model_tools.exe tests/TEST_model_tools.nim
```

Set the snapshot compile option to also verify declaration/variant coverage and compile
and exercise its generated models:

```powershell
nim c -r -d:boxcarsRustdoc=local/nimboxcarsTools/boxcars.json --out:bin/debug/test_model_tools.exe tests/TEST_model_tools.nim
```
