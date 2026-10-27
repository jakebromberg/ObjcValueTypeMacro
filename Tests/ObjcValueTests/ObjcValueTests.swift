import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import ObjcValueMacros

final class ObjcValueTests: XCTestCase {
    func testObjcValueMacro() throws {
        assertMacroExpansion(
            """
            @ObjcValue
            struct Person {
                let name: String
                let age: Int
            }
            """,
            expandedSource: """
            struct Person {
                let name: String
                let age: Int
            }

            // TODO: Generated Objective-C compatible type for @ObjcValue
            struct Person {
                let name: String
                let age: Int
            }
            """,
            macros: testMacros
        )
    }
}

let testMacros: [String: Macro.Type] = [
    "ObjcValue": ObjcValueMacro.self,
]
