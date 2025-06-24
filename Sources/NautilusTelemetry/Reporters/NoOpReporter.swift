//
//  NoOpReporter.swift
//
//
//  Created by Ladd Van Tol on 11/30/21.
//

import Foundation

public final class NoOpReporter: NautilusTelemetryReporter {

	// MARK: Lifecycle

	public init() { }

	// MARK: Public

	public var flushInterval: TimeInterval {
		1
	}

	public func reportSpans(_: [Span]) { }

	public func reportInstruments(_: [Instrument]) { }

	public func subscribeToLifecycleEvents() { }
}
