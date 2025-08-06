//
//  Baggage.swift
//
//
//  Created by Van Tol, Ladd on 11/15/21.
//

import Foundation
import os

// MARK: - SubtraceLinking

public enum SubtraceLinking {
	case none // don't link subtraces
	case up // link from child to parent
	case down // link from parent to child
	case bidirectional // link both directions
}

// MARK: - Baggage

public final class Baggage: @unchecked Sendable {

	// MARK: Lifecycle

	/// Creates a baggage object.
	/// - Parameters:
	///   - span: a parent span.
	///   - subTraceId: an optional TraceId, overriding the parent span's, allowing for the creation of subtraces.
	///   - subtraceLinking: whether to link between subtrace and parent trace, and in which direction(s)
	public init(span: Span, subTraceId: TraceId? = nil, subtraceLinking: SubtraceLinking = .bidirectional) {
		self.span = span
		self.subTraceId = subTraceId
		self.subtraceLinking = subtraceLinking
	}

	// MARK: Internal

	/// TaskLocal works even for conventional threads: https://developer.apple.com/documentation/swift/tasklocal
	@TaskLocal static var currentBaggageTaskLocal: Baggage?

	let span: Span
	let subTraceId: TraceId?
	let subtraceLinking: SubtraceLinking
}
