// Created by Ladd Van Tol on 8/25/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import XCTest
@testable import NautilusTelemetry

final class TracerTests: XCTestCase {
	class TestReporter: NautilusTelemetryReporter {

		// MARK: Lifecycle

		init(
			_ test: XCTestCase,
			idleExpectation: XCTestExpectation
		) {
			self.test = test
			self.idleExpectation = idleExpectation
		}

		// MARK: Internal

		let test: XCTestCase
		let idleExpectation: XCTestExpectation

		/// Shorten the idle timeout for the test
		var idleTimeoutInterval: TimeInterval { 0.1 }

		func reportSpans(_: [Span]) { }

		func reportInstruments(_: [any Instrument]) { }

		func subscribeToLifecycleEvents() { }

		func idleTimeout() {
			idleExpectation.fulfill()
		}
	}

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

	func testFlushTrace() {
		let originalRoot = tracer.root
		let originalTraceId = tracer.traceId

		XCTAssertFalse(originalRoot.ended)

		let childSpan = tracer.startSpan(name: "test-child")
		childSpan.end()

		tracer.flushTrace()

		XCTAssertTrue(originalRoot.ended)

		let newRoot = tracer.root
		XCTAssertNotIdentical(originalRoot, newRoot)

		let newTraceId = tracer.traceId
		XCTAssertNotEqual(originalTraceId, newTraceId)
		XCTAssertEqual(newRoot.traceId, newTraceId)

		XCTAssertFalse(newRoot.ended)

		XCTAssertEqual(tracer.retiredSpans.count, 0)
	}

	func testIdleTimeout() {
		InstrumentationSystem.resetBootstrapForTests()

		let expectation = expectation(description: "Idle received")
		let reporter = TestReporter(self, idleExpectation: expectation)
		InstrumentationSystem.bootstrap(reporter: reporter)

		let span = InstrumentationSystem.tracer.startSpan(name: "retire test")
		span.end()

		waitForExpectations(timeout: 10)
	}

	func testTracerRootSpanIsRoot() {
		let tracer = Tracer()
		let root = tracer.root

		XCTAssertTrue(root.isRoot)
		XCTAssertEqual(root.name, "root")
		XCTAssertEqual(root.kind, .internal)
		XCTAssertNil(root.parentId)
	}

	func testTracerRootSpanIsRootAfterFlush() {
		let tracer = Tracer()
		let originalRoot = tracer.root

		XCTAssertTrue(originalRoot.isRoot)

		tracer.flushTrace()

		let newRoot = tracer.root
		XCTAssertTrue(newRoot.isRoot)
		XCTAssertNotIdentical(originalRoot, newRoot)
	}

	func testTracerChildSpanIsNotRoot() {
		let tracer = Tracer()
		let childSpan = tracer.startSpan(name: "child")

		XCTAssertFalse(childSpan.isRoot)
		XCTAssertEqual(childSpan.parentId, tracer.root.id)
	}

}
