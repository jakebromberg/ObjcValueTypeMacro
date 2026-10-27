@attached(peer, names: prefixed(Immutable), prefixed(Mutable))
public macro ObjcValue() = #externalMacro(module: "ValueMacros", type: "ObjcValueMacro")
