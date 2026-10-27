import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Generates `Immutable<Name>` and `Mutable<Name>` Objective-C classes from an `@objc` protocol.
///
/// The protocol must inherit `NSCopying` and `NSMutableCopying`, and declare only `{ get }` properties.
/// Both classes are `final` `NSObject` subclasses registered with the Objective-C runtime under their
/// unmangled Swift names. `copy` returns an immutable value (the receiver itself when it is already
/// immutable), `mutableCopy` returns a new mutable value, and `isEqual(_:)`/`hash` compare property
/// values across both classes, so property types must be `Hashable`.
///
/// As a member macro it also adds `copy()` and `mutableCopy()` requirements to the protocol, because
/// `NSCopying` only declares `copyWithZone:` and Objective-C callers holding an `id<Name>` need `-copy`.
public struct ObjcValueMacro {
    struct Property {
        let name: String
        let type: String
        let isSettable: Bool
    }
}

extension ObjcValueMacro: PeerMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let proto: ProtocolDeclSyntax, properties: [Property]
        switch validate(decl) {
        case .success(let valid):
            (proto, properties) = valid
        case .failure(let error):
            context.diagnose(Diagnostic(node: attribute, message: error))
            return []
        }
        let name = proto.name.text
        let access = proto.modifiers
            .first { ["public", "package"].contains($0.name.text) }
            .map { "\($0.name.text) " } ?? ""
        return [
            makeClass(prefix: "Immutable", binding: "let", copy: "self", protocolName: name, properties: properties, access: access),
            makeClass(prefix: "Mutable", binding: "var", copy: "Immutable\(name)(self)", protocolName: name, properties: properties, access: access),
        ]
    }

    /// Returns the protocol and its properties, or the reason the macro can't support the declaration.
    static func validate(_ decl: some SyntaxProtocol) -> Result<(ProtocolDeclSyntax, [Property]), ObjcValueDiagnostic> {
        func fail(_ message: String) -> Result<(ProtocolDeclSyntax, [Property]), ObjcValueDiagnostic> {
            .failure(ObjcValueDiagnostic(message: message))
        }
        guard let proto = decl.as(ProtocolDeclSyntax.self) else {
            return fail("@ObjcValue can only be applied to a protocol")
        }
        let name = proto.name.text
        guard proto.attributes.contains(where: { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "objc" }) else {
            return fail("@ObjcValue requires an @objc protocol so Objective-C can see the generated classes")
        }
        let inherited = Set(proto.inheritanceClause?.inheritedTypes.map(\.type.trimmedDescription) ?? [])
        guard inherited.isSuperset(of: ["NSCopying", "NSMutableCopying"]) else {
            return fail("'\(name)' must inherit NSCopying and NSMutableCopying")
        }
        let properties = properties(of: proto)
        guard !properties.contains(where: \.isSettable) else {
            return fail("'Immutable\(name)' cannot conform because '\(name)' requires a settable property; declare it '{ get }'")
        }
        return .success((proto, properties))
    }

    private static func properties(of proto: ProtocolDeclSyntax) -> [Property] {
        proto.memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  let binding = variable.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let type = binding.typeAnnotation?.type,
                  case .accessors(let accessors)? = binding.accessorBlock?.accessors
            else { return nil }
            return Property(
                name: identifier.identifier.text,
                type: type.trimmedDescription,
                isSettable: accessors.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
            )
        }
    }

    private static func makeClass(
        prefix: String,
        binding: String,
        copy: String,
        protocolName name: String,
        properties: [Property],
        access: String
    ) -> DeclSyntax {
        let className = prefix + name
        let storage = properties.map { "\(access)\(binding) \($0.name): \($0.type)" }
        let initializer = properties.isEmpty
            ? "@objc override init() {\nsuper.init()\n}"
            : """
            @objc \(access)init(\(properties.map { "\($0.name): \($0.type)" }.joined(separator: ", "))) {
            \(properties.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n"))
            super.init()
            }
            """
        let comparison = properties.isEmpty
            ? "return object is any \(name)"
            : """
            guard let other = object as? any \(name) else {
            return false
            }
            return \(properties.map { "\($0.name) == other.\($0.name)" }.joined(separator: " && "))
            """
        let hash = properties.isEmpty
            ? "return 0"
            : """
            var hasher = Hasher()
            \(properties.map { "hasher.combine(\($0.name))" }.joined(separator: "\n"))
            return hasher.finalize()
            """
        let members = storage + [
            initializer,
            """
            \(access)convenience init(_ other: any \(name)) {
            self.init(\(properties.map { "\($0.name): other.\($0.name)" }.joined(separator: ", ")))
            }
            """,
            "\(access)func copy(with zone: NSZone? = nil) -> Any {\n\(copy)\n}",
            "\(access)func mutableCopy(with zone: NSZone? = nil) -> Any {\nMutable\(name)(self)\n}",
            "\(access)override func isEqual(_ object: Any?) -> Bool {\n\(comparison)\n}",
            "\(access)override var hash: Int {\n\(hash)\n}",
        ]
        return """
            @objc(\(raw: className)) \(raw: access)final class \(raw: className): NSObject, \(raw: name) {
            \(raw: members.joined(separator: "\n"))
            }
            """
    }
}

extension ObjcValueMacro: MemberMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        providingMembersOf decl: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // The peer role reports why an invalid declaration is rejected; leave it unchanged here.
        guard case .success(let (proto, _)) = validate(decl) else { return [] }
        let declared = Set(proto.memberBlock.members.compactMap { $0.decl.as(FunctionDeclSyntax.self)?.name.text })
        return ["copy", "mutableCopy"]
            .filter { !declared.contains($0) }
            .map { "func \(raw: $0)() -> Any" }
    }
}

struct ObjcValueDiagnostic: DiagnosticMessage, Error {
    let message: String
    var severity: DiagnosticSeverity { .error }
    var diagnosticID: MessageID { MessageID(domain: "ObjcValue", id: "error") }
}
