import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(ObjcValueMacros)
import ObjcValueMacros

let testMacros: [String: Macro.Type] = [
    "ObjcValue": ObjcValue.self,
]
#endif

final class ObjcValueTests: XCTestCase {
//    func testMacro() throws {
//        #if canImport(ObjcValueMacros)
//        assertMacroExpansion(
//            """
//            #stringify(a + b)
//            """,
//            expandedSource: """
//            (a + b, "a + b")
//            """,
//            macros: testMacros
//        )
//        #else
//        throw XCTSkip("macros are only supported when running tests for the host platform")
//        #endif
//    }
//
//    func testMacroWithStringLiteral() throws {
//        #if canImport(ObjcValueMacros)
//        assertMacroExpansion(
//            #"""
//            #stringify("Hello, \(name)")
//            """#,
//            expandedSource: #"""
//            ("Hello, \(name)", #""Hello, \(name)""#)
//            """#,
//            macros: testMacros
//        )
//        #else
//        throw XCTSkip("macros are only supported when running tests for the host platform")
//        #endif
//    }
    
    func testObjcValue() throws {
        #if canImport(ObjcValueMacros)
        assertMacroExpansion(
            """
            @ObjcValue
            class Foo: NSObject {
                let x: Int
                
                init(x: Int) {
                    self.x = x
                }
            }
            """,
            expandedSource: """
            class Foo: NSObject {
                let x: Int
                
                init(x: Int) {
                    self.x = x
                }
            }

            extension Foo {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
    
    func testObjcValueFailsForObjectsThatDoNotInheritFromNSObject() throws {
        #if canImport(ObjcValueMacros)
        assertMacroExpansion(
            """
            @ObjcValue
            class Foo {
                let x: Int
                
                init(x: Int) {
                    self.x = x
                }
            }
            """,
            expandedSource: """
            class Foo {
                let x: Int
                
                init(x: Int) {
                    self.x = x
                }
            }
            """,
            diagnostics: [
              DiagnosticSpec(
                message: "ObjcValueError(message: \"Types must inherit from NSObject\")",
                line: 1,
                column: 1
              )
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
