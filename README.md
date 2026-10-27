# ObjcValue

A Swift macro that generates Objective-C classes with value-like semantics, in the style of `NSString` and `NSMutableString`, from a single protocol.

## Usage

```swift
import Foundation
import ObjcValue

@ObjcValue
@objc public protocol Person: NSCopying, NSMutableCopying {
    var name: String { get }
    var age: Int { get }
}
```

This generates two `final` `NSObject` subclasses that conform to `Person`:

| Class | Properties | `copy` | `mutableCopy` |
|---|---|---|---|
| `ImmutablePerson` | `let` (`readonly` in Objective-C) | returns `self` | new `MutablePerson` |
| `MutablePerson` | `var` (read-write in Objective-C) | new `ImmutablePerson` snapshot | new `MutablePerson` |

Both classes get `@objc init(name:age:)` (`-initWithName:age:`), `init(_ other: any Person)`, and `isEqual(_:)`/`hash` that compare property values, so an `ImmutablePerson` and a `MutablePerson` with the same values are equal. The classes are registered with the Objective-C runtime under their unmangled Swift names, and they are `public` when the protocol is.

The macro also adds `func copy() -> Any` and `func mutableCopy() -> Any` requirements to the protocol, unless it already declares them. `NSCopying` only declares `copyWithZone:`, so without these, Objective-C code holding an `id<Person>` couldn't call `-copy`.

From Objective-C:

```objc
MutablePerson *draft = [[MutablePerson alloc] initWithName:@"Ada" age:36];
draft.age = 37;
id<Person> person = [draft copy];        // an ImmutablePerson
MutablePerson *edit = [person mutableCopy];
```

## Requirements

The macro reports an error when the protocol:

- isn't `@objc`,
- doesn't inherit both `NSCopying` and `NSMutableCopying`, or
- declares a `{ get set }` property.

Property types must be Objective-C representable (because the protocol is `@objc`) and `Hashable` (for `isEqual(_:)` and `hash`).

## Limits

- A reference typed `any Person` may point at a `MutablePerson` that someone else mutates. Use `ImmutablePerson` as the type, or a `@NSCopying` property, when you need a stable value.
- The macro sees syntax only, so it doesn't deep-copy properties whose types are themselves `NSCopying`.
- Objective-C class names are the Swift names; there is no prefix option yet.

## Building and testing

```sh
swift build
swift test
swift run Examples
```

`ObjcValueTests` checks the macro's expansions and diagnostics. `ObjcValueRuntimeTests` checks the generated classes through the Objective-C runtime: class names, read-only property attributes, protocol methods, copying, and equality.
