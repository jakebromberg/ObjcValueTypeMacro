@import XCTest;
@import ExampleModels;

/// Uses the generated User classes from Objective-C, through the header Swift emits for ExampleModels.
@interface ObjCInteropTests : XCTestCase
@end

@implementation ObjCInteropTests

- (void)testCopyOfImmutableUserIsTheSameObject {
    ImmutableUser *user = [[ImmutableUser alloc] initWithName:@"Ada" email:@"ada@example.com"];
    XCTAssertEqual([user copy], user);
}

- (void)testCopyOfMutableUserIsAnImmutableSnapshot {
    MutableUser *draft = [[MutableUser alloc] initWithName:@"Ada" email:@"ada@example.com"];
    id<User> snapshot = [draft copy];
    draft.email = @"ada@lovelace.dev";

    XCTAssertTrue([(id)snapshot isKindOfClass:[ImmutableUser class]]);
    XCTAssertEqualObjects(snapshot.email, @"ada@example.com");
    XCTAssertFalse([snapshot isEqual:draft]);
}

- (void)testMutableCopyThroughTheProtocolIsIndependent {
    id<User> user = [[ImmutableUser alloc] initWithName:@"Ada" email:@"ada@example.com"];
    MutableUser *edit = [user mutableCopy];
    XCTAssertEqualObjects(edit, user);
    XCTAssertEqual(edit.hash, user.hash);

    edit.name = @"Grace";
    XCTAssertEqualObjects(user.name, @"Ada");
}

@end
