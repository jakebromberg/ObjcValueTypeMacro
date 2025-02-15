import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ConfigurationMacro: PeerMacro {
  enum ConfigurationMacroError: CustomStringConvertible, Error {
    case requiresProtocol
    case requiresObjcProtocol
    case requiresNSObjectProtocol
    case invalidPropertyName
    
    var description: String {
      switch self {
      case .requiresProtocol: return "@Configuration can only be applied to a protocol"
      case .requiresObjcProtocol: return "The protocol must be annotated with @objc"
      case .requiresNSObjectProtocol: return "The protocol must inherit from NSObjectProtocol"
      case .invalidPropertyName: return "Invalid property name"
      }
    }
  }
  
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
      throw ConfigurationMacroError.requiresProtocol
    }
    
    guard protocolDecl.attributes.hasObjCAttribute else {
      throw ConfigurationMacroError.requiresObjcProtocol
    }
    
    guard let inheritanceClause = protocolDecl.inheritanceClause,
          inheritanceClause.inheritedTypes.contains(where: { $0.type.trimmedDescription == "NSObjectProtocol" }) else {
      throw ConfigurationMacroError.requiresNSObjectProtocol
    }
    
    let protocolName = protocolDecl.name.text
    let immutableClassName = protocolName.replacingOccurrences(of: "Protocol", with: "")
    let mutableClassName = immutableClassName.replacingOccurrences(of: "Configuration", with: "MutableConfiguration")
    let properties: [VariableDeclSyntax] = protocolDecl.memberBlock.members.compactMap { member in
      member.decl.as(VariableDeclSyntax.self)
    }
    let immutableClass = try createClass(
      name: immutableClassName,
      protocolName: protocolName,
      properties: properties,
      isMutable: false
    )
    let mutableClass = try createClass(
      name: mutableClassName,
      protocolName: protocolName,
      properties: properties,
      isMutable: true
    )
    
    return [
      DeclSyntax(immutableClass),
      DeclSyntax(mutableClass),
    ]
  }
  
  private static func createClass(name: String, protocolName: String, properties: [VariableDeclSyntax], isMutable: Bool) throws -> ClassDeclSyntax {
    let classDecl = try ClassDeclSyntax("final class \(raw: name): NSObject, NSMutableCopying, \(raw: protocolName)") {
      for property in properties {
        let pattern = property.bindings.first!.pattern
        let type = property.bindings.first!.typeAnnotation!.type
        
        if isMutable {
          MemberBlockItemSyntax(decl: VariableDeclSyntax(
            bindingSpecifier: .keyword(.var),
            bindings: PatternBindingListSyntax {
              PatternBindingSyntax(
                pattern: pattern,
                typeAnnotation: TypeAnnotationSyntax(type: type)
              )
            }
          ))
        } else {
          MemberBlockItemSyntax(decl: VariableDeclSyntax(
            bindingSpecifier: .keyword(.let),
            bindings: PatternBindingListSyntax {
              PatternBindingSyntax(
                pattern: pattern,
                typeAnnotation: TypeAnnotationSyntax(type: type)
              )
            }
          ))
        }
      }
      
      try createInitializer(properties: properties)
      
      let name = isMutable ? name : name.replacingOccurrences(of: "Configuration", with: "MutableConfiguration")
      try createMutableCopyWithZone(mutableClassName: name, properties: properties)
      try createAnyMutableCopyWithZone(mutableClassName: name, properties: properties)
      try createMutableCopy(mutableClassName: name, properties: properties)
    }
    return classDecl
  }
  
  private static func createInitializer(properties: [VariableDeclSyntax]) throws -> DeclSyntax {
    let parameters: [FunctionParameterSyntax] = properties.map { property -> FunctionParameterSyntax in
      let name = property.bindings.first!.pattern
      let type = property.bindings.first!.typeAnnotation!.type
      return createFunctionParameter(name: name, type: type)
    }.map { param in
      param.with(\.trailingComma, .commaToken())
    }
    
    let lastIndex = parameters.count - 1
    let parametersWithoutTrailingComma = parameters.enumerated().map { (index, parameter) in
      index == lastIndex ? parameter.with(\.trailingComma, nil) : parameter
    }
    
    return DeclSyntax(
      try InitializerDeclSyntax("init(\(raw: parametersWithoutTrailingComma.map { $0.trimmedDescription }.joined()))") {
        for property in properties {
          let name = property.bindings.first!.pattern
          CodeBlockItemSyntax(item: .stmt(StmtSyntax("\(raw: "self.\(name)") = \(raw: name);")))
        }
      }
    )
  }
  
  private static func createFunctionParameter(name: PatternSyntax, type: TypeSyntax) -> FunctionParameterSyntax {
    if let identifierPattern = name.as(IdentifierPatternSyntax.self) {
      let identifierToken = identifierPattern.identifier
      return FunctionParameterSyntax(firstName: identifierToken, colon: .colonToken(), type: type)
    } else {
      // Handle cases where the pattern is not an identifier
      // For example, you might want to throw an error or provide a default
      fatalError("Parameter name is not an identifier.")
    }
  }
  
  private static func createAnyMutableCopyWithZone(mutableClassName: String, properties: [VariableDeclSyntax]) throws -> DeclSyntax  {
    // Explicit type for the arguments array:
    let arguments: [LabeledExprSyntax] = properties.map { property -> LabeledExprSyntax in
      let name = property.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
      return LabeledExprSyntax(label: name, expression: ExprSyntax("\(raw: name)"))
    }.map { arg in
      arg.with(\.trailingComma, .commaToken())
    }
    
    let lastIndex = arguments.count - 1
    let argumentsWithoutTrailingComma = arguments.enumerated().map { (index, argument) in
      index == lastIndex ? argument.with(\.trailingComma, nil) : argument
    }
    
    return DeclSyntax(
      try FunctionDeclSyntax("func mutableCopy(with: NSZone?) -> Any") {
        ExprSyntax("return \(raw: mutableClassName)(\(raw: argumentsWithoutTrailingComma.map { $0.trimmedDescription }.joined()))")
      }
    )
  }
  
  private static func createMutableCopyWithZone(mutableClassName: String, properties: [VariableDeclSyntax]) throws -> DeclSyntax  {
    let arguments: [LabeledExprSyntax] = properties.map { property -> LabeledExprSyntax in
      let name = property.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
      return LabeledExprSyntax(label: name, expression: ExprSyntax("\(raw: name)"))
    }.map { arg in
      arg.with(\.trailingComma, .commaToken())
    }
    
    let lastIndex = arguments.count - 1
    let argumentsWithoutTrailingComma = arguments.enumerated().map { (index, argument) in
      index == lastIndex ? argument.with(\.trailingComma, nil) : argument
    }
    
    return DeclSyntax(
      try FunctionDeclSyntax("func mutableCopy(with: NSZone?) -> \(raw: mutableClassName)") {
        ExprSyntax("return \(raw: mutableClassName)(\(raw: argumentsWithoutTrailingComma.map { $0.trimmedDescription }.joined()))")
      }
    )
  }
  
  private static func createMutableCopy(mutableClassName: String, properties: [VariableDeclSyntax]) throws -> DeclSyntax  {
    let arguments: [LabeledExprSyntax] = properties.map { property -> LabeledExprSyntax in
      let name = property.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
      return LabeledExprSyntax(label: name, expression: ExprSyntax("\(raw: name)"))
    }.map { arg in
      arg.with(\.trailingComma, .commaToken())
    }
    
    let lastIndex = arguments.count - 1
    let argumentsWithoutTrailingComma = arguments.enumerated().map { (index, argument) in
      index == lastIndex ? argument.with(\.trailingComma, nil) : argument
    }
    
    return DeclSyntax(
      try FunctionDeclSyntax("func mutableCopy() -> \(raw: mutableClassName)") {
        ExprSyntax("return \(raw: mutableClassName)(\(raw: argumentsWithoutTrailingComma.map { $0.trimmedDescription }.joined()))")
      }
    )
  }
}

extension AttributeListSyntax {
  var hasObjCAttribute: Bool {
    contains { element in
      switch element {
      case .attribute(let attributed):
        return attributed.attributeName.description.contains("objc")
      default:
        return false
      }
    }
  }
}

@main
struct ConfigurationPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    ConfigurationMacro.self,
  ]
}
