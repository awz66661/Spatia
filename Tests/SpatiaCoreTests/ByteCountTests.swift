import XCTest
@testable import SpatiaCore

final class ByteCountTests: XCTestCase {
    func testZeroBytesUsesStableNumericKilobyteText() {
        XCTAssertEqual(ByteCount.string(0), "0 KB")
        XCTAssertEqual(ByteCount.string(-1), "0 KB")
    }
}
