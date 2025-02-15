import Foundation
import Configuration
import ConfigurationMacros

@objc @Configuration protocol FooConfigurationProtocol: NSObjectProtocol {
  var bar: Int { get }
  var baz: String { get }
  var qux: Bool { get }
}

let config = FooConfiguration(bar: 42, baz: "hello", qux: true)
print(config.bar)
print(config.baz)
print(config.qux)

let mutableConfig: FooMutableConfiguration = config.mutableCopy()
mutableConfig.bar = 123
mutableConfig.baz = "world"
mutableConfig.qux = false

func printConfig(_ config: FooConfigurationProtocol) {
  print("Config via protocol: bar=\(config.bar), baz=\(config.baz), qux=\(config.qux)")
}
printConfig(config)
printConfig(mutableConfig)
