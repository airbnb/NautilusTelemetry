//
//  SpanTests.swift
//  
//
//  Created by Van Tol, Ladd on 9/27/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class SpanTests: XCTestCase {
	
	enum TestError: Error {
		case failure
	}
	
	let tracer = Tracer()
	
	let iterations = 100
	
	override func tearDown() {
		tracer.flushRetiredSpans()
	}
	
	func testTraceId() {
		let traceId = Identifiers.generateTraceId()
		XCTAssertEqual(traceId.count, 16)
		XCTAssertNotEqual(traceId, Data(repeating: 0, count: 16))
		
		let serial = DispatchQueue(label: "serial")
		var set = Set<Data>()
		
		DispatchQueue.concurrentPerform(iterations: iterations) { _ in
			let traceId = Identifiers.generateTraceId()
			_ = serial.sync { set.insert(traceId) }
		}
		
		XCTAssert(set.count == iterations) // check for duplicates
	}
	
	func testSpanId() {
		let spanId = Identifiers.generateSpanId()
		XCTAssertEqual(spanId.count, 8)
		XCTAssertNotEqual(spanId, Data(repeating: 0, count: 8))
		
		let serial = DispatchQueue(label: "serial")
		var set = Set<Data>()
		
		DispatchQueue.concurrentPerform(iterations: iterations) { _ in
			let traceId = Identifiers.generateSpanId()
			_ = serial.sync { set.insert(traceId) }
		}
		
		XCTAssert(set.count == iterations) // check for duplicates
	}

	let traceParentValueRegex_Sampling = /00-[a-f0-9]{32}-[a-f0-9]{16}-01/
	let traceParentValueRegex_NotSampling = /00-[a-f0-9]{32}-[a-f0-9]{16}-00/

	func testTrace() throws {
		
		// we expect this test to run on main queue
		dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
		
		try tracer.withSpan(name: "span1") {
			XCTAssert(tracer.currentBaggage.span.parentId != nil)
			try span2Run()
			tracer.currentSpan.addEvent(Span.Event(name: "event1"))
		}
		
		XCTAssert(tracer.retiredSpans.count == 2)
		
		let span2 = tracer.retiredSpans[0]
		XCTAssert(span2.events?.count == 2)
		XCTAssert(span2.status == .ok)
		
		let traceParentHeader = span2.traceParentValue(sampled: true)
		XCTAssertEqual(traceParentHeader.0, "traceparent")

		XCTAssert(try traceParentValueRegex_Sampling.wholeMatch(in: traceParentHeader.1) != nil)
	}

	func testTraceWithError() throws {

		// we expect this test to run on main queue
		dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

		try tracer.withSpan(name: "span1") {
			XCTAssert(tracer.currentBaggage.span.parentId != nil)
			try span2Run()
			tracer.currentSpan.recordError(TestError.failure, includeBacktrace: true)
			tracer.currentSpan.addEvent(Span.Event(name: "event1"))
		}

		XCTAssert(tracer.retiredSpans.count == 2)

		let span2 = tracer.retiredSpans[0]
		XCTAssert(span2.events?.count == 2)
		XCTAssert(span2.status == .ok)

		let span1 = tracer.retiredSpans[1]
		XCTAssertEqual(span1.status, .error(message: "The operation couldn’t be completed. (NautilusTelemetryTests.SpanTests.TestError error 0.)"))

		let event = span1.events?[0]
		let backtrace = try XCTUnwrap(event?.attributes?["exception.stacktrace"] as? String)

		XCTAssert(backtrace.contains("testTraceWithError"))

		let traceParentHeader = span2.traceParentValue(sampled: false)
		XCTAssertEqual(traceParentHeader.0, "traceparent")
		XCTAssert(try traceParentValueRegex_NotSampling.wholeMatch(in: traceParentHeader.1) != nil)
	}

	func testTraceparentHeader() throws {
		let url = try XCTUnwrap(URL(string: "https://api.example.com"))
		let span = tracer.startSpan(name: "test")

		do {
			var urlRequest = URLRequest(url: url)
			span.addTraceHeadersIfSampling(&urlRequest, isSampling: true)
			let header = try XCTUnwrap(urlRequest.value(forHTTPHeaderField: "traceparent"))
			XCTAssert(try traceParentValueRegex_Sampling.wholeMatch(in: header) != nil)
		}

		do {
			var urlRequest = URLRequest(url: url)
			let span = tracer.startSpan(name: "test")
			span.addTraceHeadersIfSampling(&urlRequest, isSampling: false)
			XCTAssertNil(urlRequest.value(forHTTPHeaderField: "traceparent"))
		}

		do {
			var urlRequest = URLRequest(url: url)
			span.addTraceHeadersUnconditionally(&urlRequest, isSampling: true)
			let header = try XCTUnwrap(urlRequest.value(forHTTPHeaderField: "traceparent"))
			XCTAssert(try traceParentValueRegex_Sampling.wholeMatch(in: header) != nil)
		}

		do {
			var urlRequest = URLRequest(url: url)
			span.addTraceHeadersUnconditionally(&urlRequest, isSampling: false)
			let header = try XCTUnwrap(urlRequest.value(forHTTPHeaderField: "traceparent"))
			XCTAssert(try traceParentValueRegex_NotSampling.wholeMatch(in: header) != nil)
		}
	}

	func testThrowing() throws {
		
		// we expect this test to run on main queue
		dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
		
		do {
			try tracer.withSpan(name: "span1") {
				throw TestError.failure
			}
		} catch {
			
		}
		
		XCTAssert(tracer.retiredSpans.count == 1)
		
		let span1 = tracer.retiredSpans[0]
		XCTAssert(span1.status != .ok)
	}
	
#if compiler(>=5.6.0) && canImport(_Concurrency)
	func testAsync() async throws {
		
		try await tracer.withSpan(name: "span1") {
			XCTAssert(tracer.currentBaggage.span.parentId != nil)
			try await span2RunAsync()
		}
		
		XCTAssert(tracer.retiredSpans.count == 2)
		
		let span2 = tracer.retiredSpans[0]
		XCTAssert(span2.events?.count == 2)
		XCTAssert(span2.status == .ok)
	}
#endif
	
	func span2Run() throws {
		var ranSpan = false
		tracer.withSpan(name: "span2") {
			
			let span = tracer.currentBaggage.span
			span.addEvent("event1")
			Thread.sleep(forTimeInterval: 0.1)
			span.addEvent("event2")
			span.status = .ok
			ranSpan = true
		}
		
		XCTAssert(ranSpan)
	}
	
	func span2RunAsync() async throws {
		var ranSpan = false
		tracer.withSpan(name: "span2async") {
			
			let span = tracer.currentBaggage.span
			span.addEvent("event1")
			Thread.sleep(forTimeInterval: 0.1)
			span.addEvent("event2")
			span.status = .ok
			ranSpan = true
		}
		
		XCTAssert(ranSpan)
	}

	func testForMemoryLeaks() throws {
		let span1 = tracer.startSpan(name: "span1")
		trackForMemoryLeak(instance: span1)

		tracer.withSpan(name: "span2") {
			let span2 = tracer.currentBaggage.span
			span2.addEvent("event1")
			Thread.sleep(forTimeInterval: 0.1)
			span2.addEvent("event2")
			span2.status = .ok

			trackForMemoryLeak(instance: span2)
		}

		tracer.flushRetiredSpans() // make sure retired spans don't show up as leaks
	}
}
