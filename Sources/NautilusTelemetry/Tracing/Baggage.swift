//
//  Baggage.swift
//
//
//  Created by Van Tol, Ladd on 11/15/21.
//

import Foundation
import os

// MARK: - SubtraceLinking

public struct SubtraceLinking: OptionSet {

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public let rawValue: Int

	/// link from child to parent
	public static let up = SubtraceLinking(rawValue: 1 << 0)

	/// link from parent to child
	public static let down = SubtraceLinking(rawValue: 1 << 1)
}

// MARK: - Baggage

public final class Baggage: @unchecked Sendable {

	// MARK: Lifecycle

	/// Creates a baggage object.
	/// - Parameters:
	///   - span: a parent span.
	///   - subTraceId: an optional TraceId, overriding the parent span's, allowing for the creation of subtraces.
	///   - subtraceLinking: whether to link between subtrace and parent trace, and in which direction(s). Defaults to bidirectional.
	public init(span: Span, subTraceId: TraceId? = nil, subtraceLinking: SubtraceLinking = [.up, .down]) {
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
