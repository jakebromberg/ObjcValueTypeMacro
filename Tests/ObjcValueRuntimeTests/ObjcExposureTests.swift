import Foundation
import ObjectiveC
import ObjcValue
import XCTest

@ObjcValue
@objc public protocol Track: NSCopying, NSMutableCopying {
    var title: String { get }
    var plays: Int { get }
}

/// Checks the generated classes through the Objective-C runtime, which is what Objective-C callers see.
final class ObjcExposureTests: XCTestCase {
    func testClassesAreRegisteredUnderUnmangledNames() {
        for name in ["ImmutableTrack", "MutableTrack"] {
            let cls: AnyClass? = NSClassFromString(name)
            XCTAssertNotNil(cls, name)
            XCTAssertTrue(cls?.superclass() == NSObject.self, name)
            XCTAssertTrue(cls?.instancesRespond(to: NSSelectorFromString("initWithTitle:plays:")) ?? false, name)
        }
    }

    func testPropertiesAreReadOnlyOnlyOnTheImmutableClass() {
        let cases: [(cls: AnyClass, property: String, readOnly: Bool)] = [
            (ImmutableTrack.self, "title", true),
            (ImmutableTrack.self, "plays", true),
            (MutableTrack.self, "title", false),
            (MutableTrack.self, "plays", false),
        ]
        for c in cases {
            guard let property = class_getProperty(c.cls, c.property),
                  let attributes = property_getAttributes(property).map({ String(cString: $0) }) else {
                XCTFail("\(c.cls).\(c.property) is not an Objective-C property")
                continue
            }
            let flags = attributes.split(separator: ",")
            XCTAssertEqual(flags.contains("R"), c.readOnly, "\(c.cls).\(c.property): \(attributes)")
        }
    }

    func testProtocolDeclaresCopyAndMutableCopyForObjcCallers() {
        for selector in ["copy", "mutableCopy"] {
            let description = protocol_getMethodDescription(Track.self, NSSelectorFromString(selector), true, true)
            XCTAssertNotNil(description.name, selector)
        }
    }

    func testCopyingFollowsFoundationConventions() throws {
        let frozen = ImmutableTrack(title: "Blue Monday", plays: 3)
        XCTAssertTrue(frozen.copy() as AnyObject === frozen, "copying an immutable value returns self")

        let thawed = try XCTUnwrap(frozen.mutableCopy() as? MutableTrack)
        thawed.plays += 1
        XCTAssertEqual(frozen.plays, 3, "mutating a mutable copy leaves the original alone")

        let refrozen = try XCTUnwrap(thawed.copy() as? ImmutableTrack)
        thawed.title = "Ceremony"
        XCTAssertEqual(refrozen.title, "Blue Monday", "copy of a mutable value is a snapshot")
        XCTAssertEqual(refrozen.plays, 4)
    }

    func testEqualityAndHashMatchAcrossVariants() {
        let frozen = ImmutableTrack(title: "Atmosphere", plays: 1)
        let thawed = MutableTrack(title: "Atmosphere", plays: 1)
        XCTAssertTrue(frozen.isEqual(thawed))
        XCTAssertTrue(thawed.isEqual(frozen))
        XCTAssertEqual(frozen.hash, thawed.hash)

        thawed.plays = 2
        XCTAssertFalse(frozen.isEqual(thawed))
        XCTAssertFalse(frozen.isEqual("Atmosphere"))
    }
}
