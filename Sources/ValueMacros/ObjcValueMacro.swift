import Foundation

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntaxBuilder

public struct ObjcValueMacro: PeerMacro {
    struct Prop {
        let name: String
        let type: String
        let isGetSet: Bool
    }
    
    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let proto = decl.as(ProtocolDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: Syntax(decl),
                                        message: SimpleMessage(message: "`@MyMacro` can only be applied to a protocol")))
            return []
        }
        
        let protoName = proto.name.text
        
        // Collect property requirements: name, type, accessor flags
        var props: [Prop] = []
        
        for member in proto.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
            // Only consider simple property requirements like: 'var x: Int { get }'
            guard
                let binding = varDecl.bindings.first,
                let ident = binding.pattern.as(IdentifierPatternSyntax.self),
                let typeAnno = binding.typeAnnotation?.type as? TypeSyntax,
                let accessor = binding.accessorBlock
            else { continue }
            
            // Detect { get } vs { get set }
            var hasGet = false, hasSet = false
            switch accessor.accessors {
            case .accessors(let list):
                for a in list {
                    let token = a.accessorSpecifier.tokenKind
                    if token == .keyword(.get) { hasGet = true }
                    if token == .keyword(.set) { hasSet = true }
                }
            case .getter:
                hasGet = true
            }
            guard hasGet else { continue } // protocol properties must at least have get
            
            props.append(.init(
                name: ident.identifier.text,
                type: typeAnno.description.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                isGetSet: hasSet
            ))
        }
        
        // If any { get set }, Immutable… cannot conform: emit a helpful diagnostic.
        if props.contains(where: { $0.isGetSet }) {
            context.diagnose(
                Diagnostic(
                    node: Syntax(proto.name),
                    message: SimpleMessage(
                        message: "`Immutable\(protoName)` cannot conform because '\(protoName)' requires a settable property. Consider removing `set` or omit the immutable class."
                    )
                )
            )
        }
        
        // Generate class source strings
        let immutableName = "Immutable\(protoName)"
        let mutableName   = "Mutable\(protoName)"
        
        // Properties
        func propsDecls(_ makeVar: (Prop) -> String) -> String {
            props.map(makeVar).joined(separator: "\n  ")
        }
        
        // Initializer signature + body
        let initParams = props.map { "\($0.name): \($0.type)" }
            .joined(separator: ", ")
        let initAssigns = props.map { "self.\($0.name) = \($0.name)" }
            .joined(separator: "\n    ")
        
        let immutableClass = """
    class \(immutableName): \(protoName) {
      \(propsDecls { p in "let \(p.name): \(p.type)" })
    
      init(\(initParams)) {
        \(initAssigns)
      }
    }
    """
        
        let mutableClass = """
    class \(mutableName): \(protoName) {
      \(propsDecls { p in "var \(p.name): \(p.type)" })
    
      init(\(initParams)) {
        \(initAssigns)
      }
    }
    """
        
        return [DeclSyntax(stringLiteral: immutableClass),
                DeclSyntax(stringLiteral: mutableClass)]
    }
}

// Minimal diagnostic message type
struct SimpleMessage: DiagnosticMessage {
    let message: String
    var severity: DiagnosticSeverity { .error }
    var diagnosticID: MessageID { .init(domain: "MyMacros", id: "error") }
}
