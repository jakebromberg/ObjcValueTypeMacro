import ExampleModels

@main
enum Example {
    static func main() {
        let draft = MutableUser(name: "Ada", email: "ada@example.com")
        draft.email = "ada@lovelace.dev"
        let user = draft.copy() as! ImmutableUser
        print("\(user.name) <\(user.email)>; equal to draft: \(user.isEqual(draft))")
    }
}
