import XCTest

@testable import ChatService

final class ReplaceFirstWordTests: XCTestCase {
    func test_replace_first_word() {
        let cases: [(String, String)] = [
            ("", ""),
            ("workspace 001", "workspace 001"),
            ("workspace001", "workspace001"),
            ("@workspace", "@project"),
            ("@workspace001", "@workspace001"),
            ("@workspace 001", "@project 001"),
        ]
        
        for (input, expected) in cases {
            let result = replaceFirstWord(in: input, from: "@workspace", to: "@project")
            XCTAssertEqual(result, expected, "Input: \(input), Expected: \(expected), Result: \(result)")
        }
    }
}

