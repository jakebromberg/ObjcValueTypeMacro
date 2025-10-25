import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `stringify` macro, which takes an expression
/// of any type and produces a tuple containing the value of that expression
/// and the source code that produced the value. For example
///
///     #stringify(x + y)
///
///  will expand to
///
///     (x + y, "x + y")
public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return "(\(argument), \(literal: argument.description))"
    }
}

public struct ObjcValue: ExtensionMacro {
    struct ObjcValueError: Error {
        let message: String
    }
    
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration:
        some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        guard let inheritedTypes = declaration.inheritanceClause?.inheritedTypes else {
            throw ObjcValueError(message: "Types must inherit from NSObject")
        }
        
        let inheritsFromNSObject = inheritedTypes.first { inheritedTypeSyntax in
            guard let text = inheritedTypeSyntax.type.firstToken(viewMode: .all)?.text else {
                return false
            }
            
            return text == "NSObject"
        }
        
        guard inheritsFromNSObject != nil else {
            throw ObjcValueError(message: "Types must inherit from NSObject")
        }
        
        let variables = declaration.memberBlock.members
          .map(\.decl)
          .compactMap { declaration -> VariableDeclSyntax? in
              guard var accessor = declaration.as(VariableDeclSyntax.self) else {
                  return nil
              }
              accessor.bindingSpecifier = .keyword(.`var`)
              
              return accessor
          }
        
        let extensionDecl = ExtensionDeclSyntax(extendedType: type) {
            "class Mutable\(type.trimmed) {\n"
            for variable in variables {
                MemberBlockItemSyntax(decl: variable)
            }
            "\n}"
        }
        
        return [extensionDecl]

    }
}

@main
struct ObjcValuePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StringifyMacro.self,
        ObjcValue.self,
    ]
}
