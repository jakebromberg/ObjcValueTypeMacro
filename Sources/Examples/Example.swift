import Foundation
import ObjcValue

@ObjcValue
@objc protocol Person: NSCopying, NSMutableCopying {
    var name: String { get }
    var age: Int { get }
}

@main
enum Example {
    static func main() {
        let draft = MutablePerson(name: "Ada", age: 36)
        draft.age += 1
        let person = draft.copy() as! ImmutablePerson
        print("\(person.name) is \(person.age); equal to draft: \(person.isEqual(draft))")
    }
}
