// Created by Ladd Van Tol on 2026-04-16.

import Testing
@testable import NautilusTelemetry
@testable import SampleCode

@Suite
struct ExampleReporterTests {

	let reporter = ExampleReporter()
	let tracer = Tracer()

	@Test("Spans without sampleRate fall back to global sampling")
	func sampledSpans_noOverride_usesGlobalSampling() {
		let span = tracer.startSpan(name: "test")
		#expect(span.sampleRate == nil)

		let result = reporter.sampledSpans([span])
		#expect(result.count == (ExampleReporter.samplingEnabled ? 1 : 0))
	}

	@Test("Spans with sampleRate 100 are always included")
	func sampledSpans_overrideAt100_alwaysIncluded() {
		let span = tracer.startSpan(name: "always")
		span.sampleRate = 100.0

		#expect(reporter.sampledSpans([span]).count == 1)
	}

	@Test("Spans with sampleRate 0 are always excluded")
	func sampledSpans_overrideAt0_alwaysExcluded() {
		let span = tracer.startSpan(name: "never")
		span.sampleRate = 0.0

		#expect(reporter.sampledSpans([span]).count == 0)
	}

}
