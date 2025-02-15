@attached(peer, names: named(FooConfiguration), named(FooMutableConfiguration)) // Placeholder names
public macro Configuration() = #externalMacro(module: "ConfigurationMacros", type: "ConfigurationMacro")
