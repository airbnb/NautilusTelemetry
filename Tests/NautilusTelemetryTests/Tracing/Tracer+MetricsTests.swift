// Created by Ladd Van Tol on 2026-04-30.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import Foundation
import Testing

@testable import NautilusTelemetry

@Suite
struct TracerMetricsTests {

	let tracer = Tracer()

	@Test
	func reportAsCounterMetricCopiesSelectedSpanAttributes() {
		let span = tracer.startSpan(name: "counterAttrSpan")
		span.addAttribute("included.string", "hello")
		span.addAttribute("excluded", "should_not_appear")

		let counter = tracer.reportAsCounterMetric(
			span: span,
			spanAttributeKeys: Set(["included.string", "included.int"])
		)

		// Attributes are collected at retire time, so this addition should be visible.
		span.addAttribute("included.int", 7)

		span.end()

		let expected: TelemetryAttributes = [
			"included.string": "hello",
			"included.int": 7,
		]
		#expect(counter.values.valueFor(attributes: expected) == 1)
	}

	@Test
	func reportAsDurationHistogramMetricCopiesSelectedSpanAttributes() throws {
		let span = tracer.startSpan(name: "histogramAttrSpan")
		span.addAttribute("route", "/users/:id")
		span.addAttribute("excluded", "nope")

		let histogram = tracer.reportAsDurationHistogramMetric(
			span: span,
			spanAttributeKeys: Set(["route", "method"])
		)

		// Attributes are collected at retire time, so this addition should be visible.
		span.addAttribute("method", "GET")
		span.adjust(start: .zero, end: .milliseconds(42))
		span.end()
		let elapsed = try #require(span.elapsed)

		let expected: TelemetryAttributes = [
			"route": "/users/:id",
			"method": "GET",
		]
		let buckets = histogram.values.values[expected]
		#expect(buckets?.count == 1)
		#expect(buckets?.sum == Int(elapsed.asMilliseconds))
	}

	@Test
	func reportAsDurationHistogramMetricHonorsUnit() throws {
		// Seconds: inject a ~2s duration so the recorded value distinguishes seconds from finer units, then
		// assert against the span's own frozen elapsed so the real wall-clock component can't cause flakiness.
		let secondsSpan = tracer.startSpan(name: "secondsDurationSpan")
		let secondsHistogram = tracer.reportAsDurationHistogramMetric(span: secondsSpan, unit: .seconds)
		secondsSpan.adjust(start: .zero, end: .seconds(2))
		secondsSpan.end()
		let secondsElapsed = try #require(secondsSpan.elapsed)

		#expect(secondsHistogram.unit?.symbol == "s")
		#expect(secondsHistogram.values.values[[:]]?.sum == Int(secondsElapsed.asSeconds))

		// Microseconds: the value is recorded from span.elapsed during end(), so assert the histogram
		// captured the span's actual elapsed converted to microseconds. Reading elapsed after end() yields
		// the same frozen value the retire callback used, so this is deterministic regardless of wall-clock timing.
		let microSpan = tracer.startSpan(name: "microDurationSpan")
		let microHistogram = tracer.reportAsDurationHistogramMetric(span: microSpan, unit: .microseconds)
		microSpan.end()
		let microElapsed = try #require(microSpan.elapsed)

		#expect(microHistogram.unit?.symbol == "µs")
		#expect(microHistogram.values.values[[:]]?.sum == Int(microElapsed.asMicroseconds))
	}

	@Test
	func reportAsDurationHistogramMetricDefaultsToMilliseconds() throws {
		let span = tracer.startSpan(name: "defaultUnitDurationSpan")
		let histogram = tracer.reportAsDurationHistogramMetric(span: span)
		span.adjust(start: .zero, end: .milliseconds(42))
		span.end()
		let elapsed = try #require(span.elapsed)

		#expect(histogram.unit?.symbol == "ms")
		#expect(histogram.values.values[[:]]?.sum == Int(elapsed.asMilliseconds))
	}

	@Test
	func reportAsCounterMetricWithNilKeysUsesEmptyAttributes() {
		let span = tracer.startSpan(name: "counterNilKeysSpan")
		span.addAttribute("any", "value")

		let counter = tracer.reportAsCounterMetric(span: span, spanAttributeKeys: nil)

		span.end()

		#expect(counter.values.valueFor(attributes: [:]) == 1)
	}

	@Test
	func reportAsCounterMetricWithNonMatchingKeysUsesEmptyAttributes() {
		let span = tracer.startSpan(name: "counterNoMatchSpan")
		span.addAttribute("present", "yes")

		let counter = tracer.reportAsCounterMetric(
			span: span,
			spanAttributeKeys: Set(["absent"])
		)

		span.end()

		#expect(counter.values.valueFor(attributes: [:]) == 1)
	}

	@Test
	func reportAsCounterMetricWithNoSpanAttributes() {
		// Exercises the `span.attributes == nil` branch in collectAttributes.
		let span = tracer.startSpan(name: "counterNoAttrSpan")

		let counter = tracer.reportAsCounterMetric(
			span: span,
			spanAttributeKeys: Set(["anything"])
		)

		span.end()

		#expect(counter.values.valueFor(attributes: [:]) == 1)
	}

	@Test
	func sharedCounterCapturesPerSpanAttributeKeys() {
		// Two spans with the same name share a cached counter, but each retire callback
		// should use its own captured spanAttributeKeys.
		let span1 = tracer.startSpan(name: "sharedCounterSpan")
		span1.addAttribute("a", "1")
		span1.addAttribute("b", "1")

		let span2 = tracer.startSpan(name: "sharedCounterSpan")
		span2.addAttribute("a", "2")
		span2.addAttribute("b", "2")

		let counter1 = tracer.reportAsCounterMetric(span: span1, spanAttributeKeys: Set(["a"]))
		let counter2 = tracer.reportAsCounterMetric(span: span2, spanAttributeKeys: Set(["b"]))
		#expect(counter1 === counter2)

		span1.end()
		span2.end()

		#expect(counter1.values.valueFor(attributes: ["a": "1"]) == 1)
		#expect(counter1.values.valueFor(attributes: ["b": "2"]) == 1)
	}

	@Test
	func collectAttributesFiltersToRequestedKeys() {
		let span = tracer.startSpan(name: "collectSpan")
		span.addAttribute("a", 1)
		span.addAttribute("b", 2)
		span.addAttribute("c", 3)

		let filtered = Tracer.collectAttributes(span, Set(["a", "c"]))
		#expect(filtered == ["a": 1, "c": 3])
	}

	@Test
	func collectAttributesReturnsEmptyForEmptyOrNilKeys() {
		let span = tracer.startSpan(name: "collectSpan")
		span.addAttribute("a", 1)

		#expect(Tracer.collectAttributes(span, nil).isEmpty)
		#expect(Tracer.collectAttributes(span, Set<String>()).isEmpty)
	}

	@Test
	func collectAttributesReturnsEmptyWhenNoKeysMatch() {
		let span = tracer.startSpan(name: "collectSpan")
		span.addAttribute("a", 1)

		#expect(Tracer.collectAttributes(span, Set(["missing"])).isEmpty)
	}
}
