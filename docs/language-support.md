# Language Support

Runtime and delivery model for each completed edition. One row is added
when a language is marked complete. Progress for languages in progress is tracked in
[release-1.md §9](specifications/release-1.md).

## Release 1 editions

| Language | Version | Runtime | 64-bit integers | Delivery | Deviations |
|---|---|---|---|---|---|
| JavaScript (reference) | 0.2.0 | Node.js 20+ | `BigInt` + `asIntN(64, …)` | Standalone CLI, no dependencies | None |
| Python | 0.3.0 | Python 3.9+ | Mask with `2**64 − 1` and sign-convert | Standalone CLI, no dependencies | None |
| C | 0.4.0 | C99 compiler (gcc/clang) + libm | int64_t / uint64_t | Standalone CLI, no dependencies | None |
| C++ | 0.5.0 | C++17 compiler (g++/clang++) | int64_t / uint64_t | Standalone CLI, no dependencies | None |
| PHP | 0.6.0 | PHP 8.0+ (64-bit build) | Native `int`; literals parsed from strings so nothing passes through `float` | Standalone CLI, no dependencies | None |
| Java | 0.7.0 | JDK 22+ (developed on 25) | Native `long`; literals parsed with `BigInteger` and reduced with `longValue()` | Standalone CLI, no dependencies | None |
| Bash | 0.8.0 | Bash 4.0+ and awk | Native `$(( ))` (signed 64-bit, wraps); literals validated as digits and parsed digit by digit; `>>>` by masking | Standalone script, needs awk | None in behaviour; awk dependency documented |
| PowerShell | 0.9.0 | PowerShell 7.2+ (`pwsh`) | Native `[long]`; literals parsed with `BigInteger`; `>>>` by masking | Standalone script, no dependencies | None in behaviour; 7.2+ required (5.1 unsupported) |
| Dart | 0.10.0 | Dart SDK 3.0+ (VM) | Native `int` (64-bit on the VM); literals parsed with `BigInt` | Standalone CLI (`dart run` or `dart compile exe`), no dependencies | None in behaviour; VM only (not dart2js) |
| TypeScript | 0.11.0 | Node.js 20+; TypeScript 5.6+ to build | `BigInt` + `asIntN(64, …)` | CLI compiled with `tsc` (`npm start`), no run-time dependencies | None in behaviour; build step required |
| Go | 0.12.0 | Go 1.21+ | Native `int64` / `uint64`; literals parsed with `math/big` | Standalone CLI (`go run` or `go build`), no dependencies | None in behaviour; POSIX needs `stty` for the selector |
| C# | 0.13.0 | .NET SDK 8+ (C# 11+) | Native `long`; literals parsed with `BigInteger`; `>>>` is built in | Standalone CLI (`dotnet run` or `dotnet publish`), no dependencies | None in behaviour; Standard Calculator lines over 20 000 characters are rejected |
| Rust | 0.14.0 | Rust 1.75+ (stable, Cargo) | Native `i64` / `u64`; literals parsed with a saturating `u128` | Standalone CLI (`cargo run` or `cargo build --release`), no dependencies | None in behaviour; POSIX needs `stty` for the selector; lines over 20 000 characters are rejected |
| Kotlin | 0.15.0 | Kotlin 1.9+ on JDK 22+ (`kotlinc`) | Native `Long`; literals parsed with `BigInteger`; `shl` / `shr` / `ushr` | Standalone CLI (`kotlinc -include-runtime` → `java -jar`), no dependencies | None in behaviour; selector uses `stty` (POSIX) or a PowerShell helper (Windows); lines over 20 000 characters are rejected |
| Swift | 0.16.0 | Swift 5.9+ (SwiftPM), Linux/macOS | Native `Int64`; `&<<` / `&>>` masking shifts; `>>>` on the `UInt64` pattern; literals accumulated in `UInt64` with overflow detection | Standalone CLI (`swift run` or `swift build -c release`), no dependencies | None in behaviour; POSIX only (Windows via WSL); selector uses `termios`; lines over 20 000 characters are rejected |

## Interface (all editions)

- On a real terminal the menus and converter pickers are arrow-key selectors: ↑↓ move, Enter selects,
  Esc or `b` goes back, `q` quits. Any other printable key opens a typed line, so numbers, names, symbols
  and one-line commands still work. Pipes, files and tests get the same screens as numbered lists.
- `ARITHMOS_PLAIN=1` forces numbered lists on a real terminal (all editions).
- `NO_COLOR=1` disables colour.
- One-shot mode exits `0` on success, `1` on an `Error [CODE]` result, `2` on bad usage.
- Every edition that can run an interactive terminal program ships the arrow-key selector; a language without a terminal is exempt and says so in its README.