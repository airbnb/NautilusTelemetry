// Created by Ladd Van Tol on 12/15/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import XCTest
@testable import NautilusTelemetry

final class RedactionTests: XCTestCase {

	func testDefaultUrlRedactionRedactsUserAndPassword() throws {
		let url = try XCTUnwrap(URL(string: "https://user:password@example.com/path"))

		let redacted = Redaction.defaultUrlRedaction(url)

		XCTAssertEqual(redacted, "https://REDACTED:REDACTED@example.com/path")
	}

	func testDefaultUrlRedactionRedactsAmzQueryParams() throws {
		let url =
			try XCTUnwrap(
				URL(string: "https://example.com/path?X-Amz-Security-Token=secret1&X-Amz-Signature=secret&other=value&X-Amz-Date=123")
			)

		let redacted = try XCTUnwrap(Redaction.defaultUrlRedaction(url))

		XCTAssert(redacted.contains("X-Amz-Security-Token=REDACTED"))
		XCTAssert(redacted.contains("X-Amz-Signature=REDACTED"))
		XCTAssert(redacted.contains("other=value"))
		XCTAssert(redacted.contains("X-Amz-Date=REDACTED"))
	}

	func testDefaultUrlRedactionPreservesRegularQueryParams() throws {
		let url = try XCTUnwrap(URL(string: "https://example.com/path?foo=bar&baz=qux"))
		let redacted = Redaction.defaultUrlRedaction(url)
		XCTAssertEqual(redacted, "https://example.com/path?foo=bar&baz=qux")
	}
}
