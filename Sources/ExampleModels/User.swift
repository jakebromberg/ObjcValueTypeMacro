import Foundation
import ObjcValue

/// A user record shared by the Swift and Objective-C examples.
///
/// `@ObjcValue` generates `ImmutableUser` and `MutableUser`, which Objective-C sees through this module's
/// generated header (`@import ExampleModels;`).
@ObjcValue
@objc public protocol User: NSObjectProtocol, NSCopying, NSMutableCopying {
    var name: String { get }
    var email: String { get }
}
