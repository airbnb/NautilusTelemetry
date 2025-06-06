// Created by Ladd Van Tol on 6/6/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import XCTest

@testable import NautilusTelemetry

final class TracerTests: XCTestCase {

	func test_startSpan_urlRequest() throws {
		let tracer = InstrumentationSystem.tracer
		tracer.isSampling = true
		let url = try XCTUnwrap(URL(string: "https://api.example.com"))
		var urlRequest = URLRequest(url: url)
		let span = tracer.startSpan(for: &urlRequest)
		XCTAssertEqual(span.name, "GET")
		let traceparentValue = urlRequest.value(forHTTPHeaderField: "traceparent")
		XCTAssertNotNil(traceparentValue)
	}
}
