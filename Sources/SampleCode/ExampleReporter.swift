//
//  ExampleReporter.swift
//  NautilusBase
//
//  Created by Ladd Van Tol on 4/6/2021.
//  Copyright © 2021 eBay Inc. All rights reserved.
//

import Foundation
import Synchronization
#if canImport(UIKit)
import UIKit
#endif
import NautilusTelemetry

// MARK: - ExampleReporter

/// An example telemetry reporter. Intended to be modified for specific use cases.
@available(iOS 13.0, *)
public class ExampleReporter: NautilusTelemetryReporter {

	// MARK: Lifecycle

	public init() {
		let configuration = URLSessionConfiguration.default
		configuration.networkServiceType = .background
		configuration.httpAdditionalHeaders = ["User-Agent": Self.userAgent]
		urlSession = URLSession(configuration: configuration)
	}

	// MARK: Public

	// MARK: Reporting
	public var flushInterval: TimeInterval {
		60
	}

	public func subscribeToLifecycleEvents() {
		#if canImport(UIKit) && os(iOS)
		let backgroundNotificationName = UIApplication.shared.supportsMultipleScenes
			? UIScene.didEnterBackgroundNotification
			: UIApplication.didEnterBackgroundNotification
		NotificationCenter.default
			.addObserver(forName: backgroundNotificationName, object: nil, queue: OperationQueue.main) { [weak self] _ in
				self?.didEnterBackground()
			}
		#endif
	}

	public func reportSpans(_ spans: [Span]) {
		let filtered = sampledSpans(spans)
		guard !filtered.isEmpty else { return }

		let additionalAttributes: TelemetryAttributes = ["sample": "value"]
		let exporter = Exporter(timeReference: timeReference)

		if let jsonPayload = try? exporter.exportOTLPToJSON(spans: filtered, additionalAttributes: additionalAttributes) {
			try? dispatchPayload(jsonPayload: jsonPayload, url: traceEndpoint)
		}
	}

	public func reportInstruments(_ instruments: [Instrument]) {
		// NOTE: This gates the entire metrics payload on the trace sampling decision. Metrics and traces
		// don't have to share a sampling decision -- an app might always emit metrics while sampling traces,
		// or sample the two at different rates. If so, replace this with a dedicated metrics sampling
		// decision here, and keep `exemplarSamplingDecision` for whether trace exemplars are attached.
		guard Self.samplingEnabled else {
			return
		}

		let additionalAttributes: TelemetryAttributes = ["sample": "value"]

		// Exemplars link a data point back to a trace, so they are only attached when that trace would be
		// sampled. We reuse the same per-span decision as `reportSpans`.
		let exporter = Exporter(timeReference: timeReference, exemplarSamplingDecision: shouldSampleSpan)

		if let jsonPayload = try? exporter.exportOTLPToJSON(instruments: instruments, additionalAttributes: additionalAttributes) {
			try? dispatchPayload(jsonPayload: jsonPayload, url: metricEndpoint)
		}
	}

	// MARK: Internal

	enum ReporterError: Error {
		case failure
	}

	static var userAgent: String = {
		let bundle = Bundle.main
		let bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
		let bundleVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
		return "\(bundleIdentifier)/\(bundleVersion)"
	}()

	static let samplerSeed = Data("OpenTelemetry".utf8)
	static let sampler = StableGuidSampler(sampleRate: 1.0, seed: samplerSeed, guid: sessionGUID)

	static var sessionGUID: Data {
		_sessionGUID.withLock { sessionGUID in
			if let guid = sessionGUID {
				return guid
			} else {
				let guid = Identifiers.generateSessionGUID()
				sessionGUID = guid
				return guid
			}
		}
	}

	static var samplingEnabled: Bool {
		sampler.guid = Self.sessionGUID
		return sampler.shouldSample
	}

	/// If collector supports brotli in the future.
	let brotliAllowed = false

	let timeReference = TimeReference(serverOffset: 0) // Ideally the offset to server time should be computed

	let traceEndpoint = URL(string: "https://api.example.com/v1/traces")!
	let metricEndpoint = URL(string: "https://api.example.com/v1/metrics")!
	let logEndpoint = URL(string: "https://api.example.com/v1/logs")!

	let urlSession: URLSession

	static func resetSessionGUID() {
		_sessionGUID.withLock {
			$0 = nil
		}
	}

	/// Filters spans based on their sample rate override, falling back to `Self.samplingEnabled` when unset.
	func sampledSpans(_ spans: [Span]) -> [Span] {
		spans.filter { shouldSampleSpan($0) }
	}

	/// The sampling decision for a single span: honor a per-span `sampleRate` override, otherwise fall back
	/// to `Self.samplingEnabled`. Used both to filter reported spans and to decide exemplar attachment.
	func shouldSampleSpan(_ span: Span) -> Bool {
		if let sampleRate = span.sampleRate {
			return StableGuidSampler(sampleRate: sampleRate, seed: Self.samplerSeed, guid: Self.sessionGUID).shouldSample
		}
		return Self.samplingEnabled
	}

	// MARK: Lifecycle events
	func didEnterBackground() {
		InstrumentationSystem.tracer.flushTrace()
		Self.resetSessionGUID()
	}

	func dispatchPayload(jsonPayload: Data, url: URL) throws {
		var compressedPayload: Data? = nil
		var contentEncoding: String? = nil

		if brotliAllowed, #available(iOS 15.0, *) {
			compressedPayload = try Compression.compressBrotli(data: jsonPayload)
			contentEncoding = "br"
		} else {
			compressedPayload = try Compression.compressDeflate(data: jsonPayload)
			contentEncoding = "deflate"
		}

		guard let compressedPayload, let contentEncoding else {
			throw ReporterError.failure
		}

		let traceIdString = Identifiers.hexEncodedString(data: InstrumentationSystem.tracer.currentSpan.traceId)
		var urlRequest = URLRequest(url: url)
		urlRequest.httpBody = compressedPayload
		urlRequest.httpMethod = "POST"
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		urlRequest.addValue(contentEncoding, forHTTPHeaderField: "Content-Encoding")
		let task = urlSession.dataTask(with: urlRequest) { _, urlResponse, error in
			if self.success(urlResponse) {
				logger.debug("\(url): success, traceId = \(traceIdString)")
			} else {
				logger.debug("\(url): error=\(String(describing: error))")
			}
		}

		// Priority is only significant for HTTP/2+ when sharing an URLSession object with other concurrent requests.
		task.priority = 0.25
		task.resume()
	}

	func success(_ urlResponse: URLResponse?) -> Bool {
		if let httpUrlResponse = urlResponse as? HTTPURLResponse {
			httpUrlResponse.statusCode == 200
		} else {
			false
		}
	}

	// MARK: Private

	static private let _sessionGUID = Mutex<Data?>(nil)

}
