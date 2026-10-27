# ObjcValue

See README.md for what the macro generates.

## Layout

- `Sources/ObjcValue` declares the public `@ObjcValue` macro (peer and member roles).
- `Sources/ValueMacros` implements it. `ObjcValueMacro.validate(_:)` holds every rule the protocol must satisfy; both roles call it, and only the peer role reports the diagnostic.
- `Tests/ObjcValueTests` uses `assertMacroExpansion` (XCTest, because swift-syntax 510's test support reports through `XCTFail`).
- `Tests/ObjcValueRuntimeTests` applies the macro for real and inspects the result with the Objective-C runtime.

## Toolchain

Build with Xcode's toolchain (`xcrun swift build`, or `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift`). The swiftly-installed Swift 6.2 on `PATH` crashes compiling swift-syntax's manifest against the Xcode 27 SDK (`unknown argument: '-target-arch-variant'`).

SwiftPM doesn't emit an Objective-C header for test targets. To check the header Objective-C sees, run `swiftc -typecheck -emit-objc-header-path <out.h> -I .build/out/Products/Debug -load-plugin-executable '.build/out/Products/Debug/ValueMacros#ValueMacros'` on a file that applies the macro.
