// Created by Jon Parise on 6/9/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import XCTest

@testable import NautilusTelemetry

final class TracerURLRequestTests: XCTestCase {
	let tracer = Tracer()
	let url = URL(string: "http://www.example.com")!

	func testStartSpanWithRequestAttributes() throws {
		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

		let span = tracer.startSpan(for: &urlRequest, template: "/users/:id", headersToCapture: Set(["content-type"]))
		XCTAssertEqual(span.name, "GET /users/:id")

		let attributes = try XCTUnwrap(span.attributes as? [String: String])
		XCTAssertEqual(attributes["server.address"], url.host())
		XCTAssertEqual(attributes["http.request.method"], urlRequest.httpMethod)
		XCTAssertEqual(attributes["http.request.header.content-type"], "application/json")
		XCTAssertEqual(attributes["url.template"], "/users/:id")
	}
}