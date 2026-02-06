# Freestanding Build Findings

Hard-won lessons from building Zig for `wasm32-freestanding` with JS FFI.

## 1. `extern "env"` vs `@import("*.js")`

Using `@import("some_module.js")` in Zig source files causes the compiler to link in `std.Thread` and `std.posix`, which fail on freestanding targets.

**Fix**: Declare FFI functions as `extern "env" fn` instead. The JavaScript host provides these functions via the WebAssembly import object at instantiation time.

```zig
// Wrong -- triggers std linkage on freestanding
extern fn env_createAudioContext() u32;

// Correct -- satisfied by JS import object
pub extern "env" fn env_createAudioContext() u32;
```

## 2. Error Sets in Exported Functions

If an exported function (even with `.entry = .disabled`) returns an error set (`!void`), the compiler links stdlib error handling components (`std.Thread`, `std.posix`) that are incompatible with freestanding.

**Fix**: Exported functions targeting WASM should return `void` or optional types, not error unions.

```zig
// Wrong -- pulls in incompatible stdlib
pub export fn main() !void { ... }

// Correct
pub export fn main() void { ... }
```

## 3. `exclude_libc` Does Not Help

Setting `exe.exclude_libc = true` in `build.zig` does not prevent the stdlib linkage issues described above. The root cause is the FFI import mechanism and error set returns, not libc specifically.

## 4. Pattern That Works

The working pattern (demonstrated by `webinput.zig` and `webaudio.zig`):

- Declare JS-provided functions as `extern "env" fn`
- Export Zig functions that JS calls back into as `pub export fn`
- Return `void`, optionals, or primitive types from exports -- never error sets
- Internal state management uses plain Zig (no `std` imports in the WASM path)
- `std` is only imported in test files (`*.test.zig`), which run on native targets
