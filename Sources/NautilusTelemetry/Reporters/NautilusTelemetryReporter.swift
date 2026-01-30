//
//  NautilusTelemetryReporter.swift
//
//
//  Created by Van Tol, Ladd on 11/29/21.
//

import Foundation

// MARK: - NautilusTelemetryReporter

public protocol NautilusTelemetryReporter: AnyObject {

	/// Desired flush interval.
	var flushInterval: TimeInterval { get }

	var idleTimeoutInterval: TimeInterval { get }

	func reportSpans(_ spans: [Span])

	func reportInstruments(_ instruments: [Instrument])

	/// Add listeners for application lifecycle events -- typically called during didFinishLaunching.
	func subscribeToLifecycleEvents()

	/// Called when no spans have been retired in `idleTimeoutInterval`
	func idleTimeout()
}

extension NautilusTelemetryReporter {
	/// Default implementations

	public var flushInterval: TimeInterval { Tracer.defaultFlushInterval }

	public var idleTimeoutInterval: TimeInterval { Tracer.defaultIdleInterval }

	public func idleTimeout() { }
}
