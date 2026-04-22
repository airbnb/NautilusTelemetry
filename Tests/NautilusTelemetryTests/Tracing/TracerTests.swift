// Created by Ladd Van Tol on 8/25/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import Synchronization
import Testing
@testable import NautilusTelemetry

@Suite
struct TracerTests {

	let tracer = Tracer()

	@Test
	func buildSpanSubtraceLinking() {
		let parent = tracer.startSpan(name: "parent")
		let baggage = Baggage(span: parent, subTraceId: Identifiers.generateTraceId(), subtraceLinking: [.down, .up])

		let child = tracer.buildSpan(name: "hello", kind: .client, attributes: nil, baggage: baggage)
		#expect(child.links.count == 1)
		#expect(child.links[0].relationship == .parent)
		#expect(child.links[0].id == parent.id)
		#expect(child.links[0].traceId == parent.traceId)

		#expect(parent.links.count == 1)
		#expect(parent.links[0].relationship == .child)
		#expect(parent.links[0].id == child.id)
		#expect(parent.links[0].traceId == child.traceId)
	}

	@Test
	func flushTrace() {
		let originalRoot = tracer.root
		let originalTraceId = tracer.traceId

		#expect(!originalRoot.ended)

		let childSpan = tracer.startSpan(name: "test-child")
		childSpan.end()

		tracer.flushTrace()

		#expect(originalRoot.ended)

		let newRoot = tracer.root
		#expect(originalRoot !== newRoot)

		let newTraceId = tracer.traceId
		#expect(originalTraceId != newTraceId)
		#expect(newRoot.traceId == newTraceId)

		#expect(!newRoot.ended)
		#expect(tracer.retiredSpans.count == 0)
	}

	@Test
	func idleTimeout() async {
		InstrumentationSystem.resetBootstrapForTests()

		class IdleTestReporter: NautilusTelemetryReporter {
			var idleTimeoutInterval: TimeInterval { 0.1 }
			let onIdleTimeout: () -> Void
			private let didFire = Mutex(false)

			init(onIdleTimeout: @escaping () -> Void) {
				self.onIdleTimeout = onIdleTimeout
			}

			func reportSpans(_: [Span]) { }
			func reportInstruments(_: [any Instrument]) { }
			func subscribeToLifecycleEvents() { }
			func idleTimeout() {
				let alreadyFired = didFire.withLock { fired in
					let was = fired
					fired = true
					return was
				}
				guard !alreadyFired else { return }
				InstrumentationSystem.tracer.flushTimer?.suspend()
				InstrumentationSystem.tracer.idleTimer?.suspend()
				onIdleTimeout()
			}
		}

		await confirmation("Idle received") { confirm in
			let reporter = IdleTestReporter { confirm() }
			InstrumentationSystem.bootstrap(reporter: reporter)

			let span = InstrumentationSystem.tracer.startSpan(name: "retire test")
			span.end()

			try? await Task.sleep(for: .seconds(10))
		}

		InstrumentationSystem.resetBootstrapForTests()
	}

	@Test
	func tracerRootSpanIsRoot() {
		let tracer = Tracer()
		let root = tracer.root

		#expect(root.isRoot)
		#expect(root.name == "root")
		#expect(root.kind == .internal)
		#expect(root.parentId == nil)
	}

	@Test
	func tracerRootSpanIsRootAfterFlush() {
		let tracer = Tracer()
		let originalRoot = tracer.root

		#expect(originalRoot.isRoot)

		tracer.flushTrace()

		let newRoot = tracer.root
		#expect(newRoot.isRoot)
		#expect(originalRoot !== newRoot)
	}

	@Test
	func tracerChildSpanIsNotRoot() {
		let tracer = Tracer()
		let childSpan = tracer.startSpan(name: "child")

		#expect(!childSpan.isRoot)
		#expect(childSpan.parentId == tracer.root.id)
	}

	// MARK: - Baggage Attribute Propagation Tests

	@Test
	func baggageAttributesPropagateToSpan() {
		let parent = tracer.startSpan(name: "parent")
		let baggage = Baggage(span: parent)
		baggage["baggage.key"] = "baggage.value"

		let child = tracer.buildSpan(name: "child", baggage: baggage)
		#expect(child["baggage.key"] as? String == "baggage.value")
	}

	@Test
	func spanAttributesOverrideBaggageAttributes() {
		let parent = tracer.startSpan(name: "parent")
		let baggage = Baggage(span: parent)
		baggage["shared.key"] = "from.baggage"

		let spanAttributes: TelemetryAttributes = ["shared.key": "from.span"]
		let child = tracer.buildSpan(name: "child", attributes: spanAttributes, baggage: baggage)
		#expect(child["shared.key"] as? String == "from.span")
	}

	@Test
	func mergeAttributesBothNil() {
		#expect(tracer.mergeAttributes(baggageAttributes: nil, spanAttributes: nil) == nil)
	}

	@Test
	func mergeAttributesBaggageOnlyNil() {
		let spanAttributes: TelemetryAttributes = ["span.key": "span.value"]
		let result = tracer.mergeAttributes(baggageAttributes: nil, spanAttributes: spanAttributes)
		#expect(result?["span.key"] as? String == "span.value")
	}

	@Test
	func mergeAttributesSpanOnlyNil() {
		let baggageAttributes: TelemetryAttributes = ["baggage.key": "baggage.value"]
		let result = tracer.mergeAttributes(baggageAttributes: baggageAttributes, spanAttributes: nil)
		#expect(result?["baggage.key"] as? String == "baggage.value")
	}

	// MARK: - Error Propagation Tests

	@Test
	func propagateSpanRecordsErrorOnSpan() {
		let span = tracer.startSpan(name: "test-span")
		struct TestError: Error { }

		#expect(throws: TestError.self) {
			try tracer.propagateParent(span) {
				throw TestError()
			}
		}

		#expect(span.status == .error(message: "TestError()"))
		#expect(span.events?.count == 1)
		#expect(span.events?.first?.name == "exception")
	}

	@Test
	func propagateBaggageRecordsErrorOnSpan() {
		let span = tracer.startSpan(name: "test-span")
		let baggage = Baggage(span: span)
		struct TestError: Error { }

		#expect(throws: TestError.self) {
			try tracer.propagateBaggage(baggage) {
				throw TestError()
			}
		}

		#expect(span.status == .error(message: "TestError()"))
		#expect(span.events?.count == 1)
		#expect(span.events?.first?.name == "exception")
	}

	@Test
	func sampleRatePropagatedToChildSpan() {
		let parent = tracer.startSpan(name: "parent")
		parent.sampleRate = 25.0
		let child = tracer.buildSpan(name: "child", baggage: Baggage(span: parent))
		#expect(child.sampleRate == 25.0)
	}

	@Test
	func sampleRatePropagatedToSubtraceSpan() {
		let parent = tracer.startSpan(name: "parent")
		parent.sampleRate = 75.0
		let baggage = Baggage(span: parent, subTraceId: Identifiers.generateTraceId())
		let child = tracer.buildSpan(name: "child", baggage: baggage)
		#expect(child.sampleRate == 75.0)
	}

	@Test
	func metricName() {
		let span = tracer.startSpan(name: "op")
		let fileID = "MyModule/Path/File.swift"

		let prefixed: String = tracer.metricName(
			span: span,
			namingConvention: .modulePrefix,
			fileID: fileID,
			suffix: "_counter"
		)
		#expect(prefixed == "MyModule_op_counter")

		let raw: String = tracer.metricName(
			span: span,
			namingConvention: .raw,
			fileID: fileID,
			suffix: "_histogram"
		)
		#expect(raw == "op_histogram")
	}

}
