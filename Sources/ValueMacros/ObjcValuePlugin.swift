import SwiftCompilerPlugin
import SwiftSyntaxMacros

struct ObjcValuePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ObjcValueMacro.self,
    ]
}
