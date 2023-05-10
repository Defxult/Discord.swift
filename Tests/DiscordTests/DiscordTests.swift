import XCTest
@testable import Discord

final class DiscordTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Discord().text, "Hello, World!")
    }
}
