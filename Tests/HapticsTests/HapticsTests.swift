import XCTest
@testable import Haptics

final class HapticsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Haptics().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
