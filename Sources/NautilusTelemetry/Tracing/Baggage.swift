//
//  Baggage.swift
//
//
//  Created by Van Tol, Ladd on 11/15/21.
//

import Foundation
import os

public final class Baggage: @unchecked Sendable {

	// MARK: Lifecycle

	/// Creates a baggage object.
	/// - Parameters:
	///   - span: a parent span.
	///   - subTraceId: an optional TraceId, overriding the parent span's, allowing for the creation of subtraces.
	public init(span: Span, subTraceId: TraceId? = nil) {
		self.span = span
		self.subTraceId = subTraceId
	}

	// MARK: Internal

	/// TaskLocal works even for conventional threads: https://developer.apple.com/documentation/swift/tasklocal
	@TaskLocal static var currentBaggageTaskLocal: Baggage?

	let span: Span
	let subTraceId: TraceId?
}
