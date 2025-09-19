// Created by Jon Parise on 6/9/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import XCTest

@testable import NautilusTelemetry

final class TracerURLRequestTests: XCTestCase {
	let tracer = Tracer()

	func testSpanWithRequestAttributes() throws {
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

		let spans = [
			tracer.startSpan(
				request: &urlRequest,
				template: "/users/:id",
				captureHeaders: Set(["content-type"])
			),
			tracer.startSubtraceSpan(
				request: &urlRequest,
				template: "/users/:id",
				captureHeaders: Set(["content-type"])
			),
		]
		for span in spans {
			XCTAssertEqual(span.name, "GET /users/:id")

			let attributes = try XCTUnwrap(span.attributes as? [String: String])
			XCTAssertEqual(attributes["server.address"], url.host())
			XCTAssertEqual(attributes["http.request.method"], urlRequest.httpMethod)
			XCTAssertEqual(attributes["http.request.header.content-type"], "application/json")
			XCTAssertEqual(attributes["url.template"], "/users/:id")
		}
	}

	func testStartSubtraceSpanHasNewTraceID() throws {
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)

		let initialTraceID = tracer.traceId

		let span = tracer.startSubtraceSpan(
			request: &urlRequest,
			captureHeaders: Set(["content-type"])
		)

		XCTAssertNotEqual(initialTraceID, span.traceId)
		XCTAssertEqual(initialTraceID, tracer.traceId)
	}

	func testStartSpanWithRequestTraceParent() throws {
		tracer.isSampling = true
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		let span = tracer.startSpan(request: &urlRequest)

		let (headerName, headerValue) = span.traceParentHeaderValue(sampled: true)
		XCTAssertEqual(urlRequest.value(forHTTPHeaderField: headerName), headerValue)
	}

	func testTraceParentModeNever() throws {
		tracer.traceParentMode = .never
		tracer.isSampling = true

		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		let span = tracer.startSpan(request: &urlRequest)

		XCTAssertNil(urlRequest.value(forHTTPHeaderField: "traceparent"))

		span.end()
	}

	func testTraceParentModeIfSamplingSampled() throws {
		tracer.traceParentMode = .ifSampling
		tracer.isSampling = true

		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		let span = tracer.startSpan(request: &urlRequest)

		let (headerName, headerValue) = span.traceParentHeaderValue(sampled: true)
		XCTAssertEqual(urlRequest.value(forHTTPHeaderField: headerName), headerValue)

		span.end()
	}

	func testTraceParentModeIfSamplingNotSampled() throws {
		tracer.traceParentMode = .ifSampling
		tracer.isSampling = false

		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		let span = tracer.startSpan(request: &urlRequest)

		XCTAssertNil(urlRequest.value(forHTTPHeaderField: "traceparent"))

		span.end()
	}

	func testTraceParentModeUnconditionallyWhenSampled() throws {
		tracer.traceParentMode = .always
		tracer.isSampling = true

		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		let span = tracer.startSpan(request: &urlRequest)

		let (headerName, headerValue) = span.traceParentHeaderValue(sampled: true)
		XCTAssertEqual(urlRequest.value(forHTTPHeaderField: headerName), headerValue)

		span.end()
	}

	func testTraceParentModeUnconditionallyWhenNotSampled() throws {
		tracer.traceParentMode = .always
		tracer.isSampling = false

		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		let span = tracer.startSpan(request: &urlRequest)

		let (headerName, headerValue) = span.traceParentHeaderValue(sampled: false)
		XCTAssertEqual(urlRequest.value(forHTTPHeaderField: headerName), headerValue)

		span.end()
	}

	func testTraceParentModeWithSubtraceSpan() throws {
		tracer.traceParentMode = .ifSampling
		tracer.isSampling = true

		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		let span = tracer.startSubtraceSpan(request: &urlRequest)

		let (headerName, headerValue) = span.traceParentHeaderValue(sampled: true)
		XCTAssertEqual(urlRequest.value(forHTTPHeaderField: headerName), headerValue)

		span.end()
	}

	func testTraceParentModeDefaultValue() {
		XCTAssertEqual(tracer.traceParentMode, .always)
	}
}
