import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import ValueMacros

private let testMacros: [String: Macro.Type] = [
    "ObjcValue": ObjcValueMacro.self,
]

final class ObjcValueExpansionTests: XCTestCase {
    func testGeneratesObjcVisibleImmutableAndMutableClasses() {
        assertMacroExpansion(
            """
            @ObjcValue
            @objc public protocol Person: NSCopying, NSMutableCopying {
                var name: String { get }
                var age: Int { get }
            }
            """,
            expandedSource: """
            @objc public protocol Person: NSCopying, NSMutableCopying {
                var name: String { get }
                var age: Int { get }

                func copy() -> Any

                func mutableCopy() -> Any
            }

            @objc(ImmutablePerson) public final class ImmutablePerson: NSObject, Person {
                public let name: String
                public let age: Int
                @objc public init(name: String, age: Int) {
                    self.name = name
                    self.age = age
                    super.init()
                }
                public convenience init(_ other: any Person) {
                    self.init(name: other.name, age: other.age)
                }
                public func copy(with zone: NSZone? = nil) -> Any {
                    self
                }
                public func mutableCopy(with zone: NSZone? = nil) -> Any {
                    MutablePerson(self)
                }
                public override func isEqual(_ object: Any?) -> Bool {
                    guard let other = object as? any Person else {
                        return false
                    }
                    return name == other.name && age == other.age
                }
                public override var hash: Int {
                    var hasher = Hasher()
                    hasher.combine(name)
                    hasher.combine(age)
                    return hasher.finalize()
                }
            }

            @objc(MutablePerson) public final class MutablePerson: NSObject, Person {
                public var name: String
                public var age: Int
                @objc public init(name: String, age: Int) {
                    self.name = name
                    self.age = age
                    super.init()
                }
                public convenience init(_ other: any Person) {
                    self.init(name: other.name, age: other.age)
                }
                public func copy(with zone: NSZone? = nil) -> Any {
                    ImmutablePerson(self)
                }
                public func mutableCopy(with zone: NSZone? = nil) -> Any {
                    MutablePerson(self)
                }
                public override func isEqual(_ object: Any?) -> Bool {
                    guard let other = object as? any Person else {
                        return false
                    }
                    return name == other.name && age == other.age
                }
                public override var hash: Int {
                    var hasher = Hasher()
                    hasher.combine(name)
                    hasher.combine(age)
                    return hasher.finalize()
                }
            }
            """,
            macros: testMacros
        )
    }

    func testKeepsCopyRequirementsTheProtocolAlreadyDeclares() {
        assertMacroExpansion(
            """
            @ObjcValue
            @objc protocol Tag: NSCopying, NSMutableCopying {
                func copy() -> Any
                func mutableCopy() -> Any
            }
            """,
            expandedSource: """
            @objc protocol Tag: NSCopying, NSMutableCopying {
                func copy() -> Any
                func mutableCopy() -> Any
            }

            @objc(ImmutableTag) final class ImmutableTag: NSObject, Tag {
                @objc override init() {
                    super.init()
                }
                convenience init(_ other: any Tag) {
                    self.init()
                }
                func copy(with zone: NSZone? = nil) -> Any {
                    self
                }
                func mutableCopy(with zone: NSZone? = nil) -> Any {
                    MutableTag(self)
                }
                override func isEqual(_ object: Any?) -> Bool {
                    return object is any Tag
                }
                override var hash: Int {
                    return 0
                }
            }

            @objc(MutableTag) final class MutableTag: NSObject, Tag {
                @objc override init() {
                    super.init()
                }
                convenience init(_ other: any Tag) {
                    self.init()
                }
                func copy(with zone: NSZone? = nil) -> Any {
                    ImmutableTag(self)
                }
                func mutableCopy(with zone: NSZone? = nil) -> Any {
                    MutableTag(self)
                }
                override func isEqual(_ object: Any?) -> Bool {
                    return object is any Tag
                }
                override var hash: Int {
                    return 0
                }
            }
            """,
            macros: testMacros
        )
    }

    /// Each invalid declaration produces one error and no generated classes.
    func testRejectsDeclarationsItCannotSupport() {
        let cases: [(source: String, expanded: String, message: String)] = [
            (
                "@ObjcValue\nstruct Person {}",
                "struct Person {}",
                "@ObjcValue can only be applied to a protocol"
            ),
            (
                "@ObjcValue\nprotocol Person: NSCopying, NSMutableCopying {}",
                "protocol Person: NSCopying, NSMutableCopying {}",
                "@ObjcValue requires an @objc protocol so Objective-C can see the generated classes"
            ),
            (
                "@ObjcValue\n@objc protocol Person: NSCopying {}",
                "@objc protocol Person: NSCopying {}",
                "'Person' must inherit NSCopying and NSMutableCopying"
            ),
            (
                "@ObjcValue\n@objc protocol Person: NSCopying, NSMutableCopying {\n    var name: String { get set }\n}",
                "@objc protocol Person: NSCopying, NSMutableCopying {\n    var name: String { get set }\n}",
                "'ImmutablePerson' cannot conform because 'Person' requires a settable property; declare it '{ get }'"
            ),
        ]
        for c in cases {
            assertMacroExpansion(
                c.source,
                expandedSource: c.expanded,
                diagnostics: [DiagnosticSpec(message: c.message, line: 1, column: 1)],
                macros: testMacros
            )
        }
    }
}
