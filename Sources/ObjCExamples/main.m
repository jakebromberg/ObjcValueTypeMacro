@import Foundation;
@import ExampleModels;

int main(void) {
    @autoreleasepool {
        MutableUser *draft = [[MutableUser alloc] initWithName:@"Ada" email:@"ada@example.com"];
        draft.email = @"ada@lovelace.dev";

        id<User> user = [draft copy];
        draft.name = @"Grace";

        printf("%s <%s> is %s; draft is now %s\n",
               user.name.UTF8String, user.email.UTF8String,
               NSStringFromClass([(id)user class]).UTF8String, draft.name.UTF8String);
    }
    return 0;
}
