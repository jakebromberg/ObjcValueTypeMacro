/// Generates `Immutable<Name>` and `Mutable<Name>` Objective-C classes that conform to the attached protocol.
///
/// The protocol must be `@objc`, inherit `NSCopying` and `NSMutableCopying`, and declare only `{ get }`
/// properties whose types are `Hashable`:
///
/// ```swift
/// @ObjcValue
/// @objc public protocol Person: NSCopying, NSMutableCopying {
///     var name: String { get }
///     var age: Int { get }
/// }
/// ```
///
/// Objective-C sees `ImmutablePerson` with `readonly` properties and `MutablePerson` with read-write ones,
/// both with `-initWithName:age:`. `copy` and `mutableCopy` follow Foundation's conventions, and the macro
/// adds `copy()` and `mutableCopy()` requirements to the protocol so they can be called on `id<Person>`.
@attached(peer, names: prefixed(Immutable), prefixed(Mutable))
@attached(member, names: named(copy), named(mutableCopy))
public macro ObjcValue() = #externalMacro(module: "ValueMacros", type: "ObjcValueMacro")
