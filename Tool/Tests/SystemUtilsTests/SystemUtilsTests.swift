import CopilotForXcodeKit
import LanguageServerProtocol
import XCTest

@testable import Workspace
@testable import SystemUtils

final class SystemUtilsTests: XCTestCase {
    func test_get_xcode_version() async throws {
        guard let version = SystemUtils.xcodeVersion else {
            XCTFail("The Xcode version should not be nil.")
            return
        }
        let versionPattern = "^\\d+(\\.\\d+)*$"
        let versionTest = NSPredicate(format: "SELF MATCHES %@", versionPattern)
        
        XCTAssertTrue(versionTest.evaluate(with: version), "The Xcode version should match the expected format.")
        XCTAssertFalse(version.isEmpty, "The Xcode version should not be an empty string.")
    }
}
