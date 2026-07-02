import XCTest
@testable import TickleMyPickle

final class AppCopyTests: XCTestCase {
  func testUsesTheSingularForOneCourt() {
    XCTAssertEqual(AppCopy.CourtList.heading(1), "1 pickleball court nearby")
  }

  func testUsesThePluralForMultipleCourts() {
    XCTAssertEqual(AppCopy.CourtList.heading(3), "3 pickleball courts nearby")
  }

  func testUsesThePluralForZero() {
    XCTAssertEqual(AppCopy.CourtList.heading(0), "0 pickleball courts nearby")
  }
}
