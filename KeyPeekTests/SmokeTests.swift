import XCTest
@testable import KeyPeek

// Checks that the app starts with our AppDelegate in charge.
final class SmokeTests: XCTestCase {

    func testAppDelegateExists() {
        XCTAssertTrue(NSApp.delegate is AppDelegate)
    }
}
