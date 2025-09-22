// Created by Ladd Van Tol on 8/25/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import XCTest
@testable import NautilusTelemetry

final class TracerTests: XCTestCase {
	let tracer = Tracer()

	func testBuildSpanSubtraceLinking() {
		let parent = tracer.startSpan(name: "parent")
		let baggage = Baggage(span: parent, subTraceId: Identifiers.generateTraceId(), subtraceLinking: [.down, .up])

		let child = tracer.buildSpan(name: "hello", kind: .client, attributes: nil, baggage: baggage)
		XCTAssertEqual(child.links.count, 1)
		XCTAssertEqual(child.links[0].relationship, .parent)
		XCTAssertEqual(child.links[0].id, parent.id)
		XCTAssertEqual(child.links[0].traceId, parent.traceId)

		XCTAssertEqual(parent.links.count, 1)
		XCTAssertEqual(parent.links[0].relationship, .child)
		XCTAssertEqual(parent.links[0].id, child.id)
		XCTAssertEqual(parent.links[0].traceId, child.traceId)
	}
}
