import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ObjcValuePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ObjcValueMacro.self,
    ]
}
