// Created by Jon Parise on 6/9/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import XCTest

@testable import NautilusTelemetry

final class TracerURLRequestTests: XCTestCase {
	let tracer = Tracer()

	func testStartSpanWithRequestAttributes() throws {
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

		let span = tracer.startSpan(
			request: &urlRequest,
			template: "/users/:id",
			captureHeaders: Set(["content-type"])
		)
		XCTAssertEqual(span.name, "GET /users/:id")

		let attributes = try XCTUnwrap(span.attributes as? [String: String])
		XCTAssertEqual(attributes["server.address"], url.host())
		XCTAssertEqual(attributes["http.request.method"], urlRequest.httpMethod)
		XCTAssertEqual(attributes["http.request.header.content-type"], "application/json")
		XCTAssertEqual(attributes["url.template"], "/users/:id")
	}

	func testStartSpanWithRequestTraceParent() throws {
		tracer.isSampling = true
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		let span = tracer.startSpan(request: &urlRequest)

		let (headerName, headerValue) = span.traceParentHeaderValue(sampled: true)
		XCTAssertEqual(urlRequest.value(forHTTPHeaderField: headerName), headerValue)
	}
}
