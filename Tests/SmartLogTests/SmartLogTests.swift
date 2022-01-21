@testable import SmartLog
import XCTest

final class SmartLogTests: XCTestCase {
  func testExample() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    XCTAssertEqual(SmartLog().text, "Hello, World!")
  }
  
  static var allTests = [
    ("testExample", testExample),
  ]
}
