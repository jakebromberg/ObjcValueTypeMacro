import Foundation
import ObjcValue

let a = 17
let b = 25

let (result, code) = #stringify(a + b)

print("The value \(result) was produced by the code \"\(code)\"")

@ObjcValue
class Foo: NSObject {
    let x: Int
    
    init(x: Int) {
        self.x = x
    }
}
