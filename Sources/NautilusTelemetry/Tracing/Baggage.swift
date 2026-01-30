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

public final class Baggage: TelemetryAttributesContainer, @unchecked Sendable {

	// MARK: Lifecycle

	/// Creates a baggage object.
	/// - Parameters:
	///   - span: a parent span.
	///   - subTraceId: an optional TraceId, overriding the parent span's, allowing for the creation of subtraces.
	///   - subtraceLinking: whether to link between subtrace and parent trace, and in which direction(s). Defaults to bidirectional.
	///   - attributes: any attributes to be carried on the baggage
	public init(
		span: Span,
		subTraceId: TraceId? = nil,
		subtraceLinking: SubtraceLinking = [.up, .down],
		attributes: TelemetryAttributes? = nil
	) {
		self.span = span
		self.subTraceId = subTraceId
		self.subtraceLinking = subtraceLinking
		if attributes == nil {
			// Infer baggage attributes from current context if not provided
			_attributes = Baggage.currentBaggageTaskLocal?.attributes
		} else {
			_attributes = attributes
		}
	}

	// MARK: Public

	/// Adds an attribute to the baggage. This can be used to propagate selected attributes to child spans.
	/// - Parameters:
	///   - name: a name, conforming to https://github.com/open-telemetry/opentelemetry-specification/tree/main/specification/trace/semantic_conventions
	///   - value: a value.
	public func addAttribute(_ name: String, _ value: AnyHashable?) {
		guard let value else { return }

		// AnyHashable is not Sendable. For now, make this unchecked, but could consider wrapping ala:
		// https://github.com/pointfreeco/swift-concurrency-extras/blob/main/Sources/ConcurrencyExtras/AnyHashableSendable.swift
		lock.withLockUnchecked {
			if _attributes == nil {
				_attributes = TelemetryAttributes()
			}

			_attributes?[name] = value
		}
	}

	public subscript(name: String) -> AnyHashable? {
		get {
			lock.withLockUnchecked {
				_attributes?[name]
			}
		}
		set(newValue) {
			addAttribute(name, newValue)
		}
	}

	// MARK: Internal

	/// TaskLocal works even for conventional threads: https://developer.apple.com/documentation/swift/tasklocal
	@TaskLocal static var currentBaggageTaskLocal: Baggage?

	let span: Span
	let subTraceId: TraceId?
	let subtraceLinking: SubtraceLinking

	/// Vend private attributes as a thread-safe copy
	var attributes: TelemetryAttributes? {
		lock.withLockUnchecked { _attributes }
	}

	// MARK: Private

	private let lock = OSAllocatedUnfairLock()

	/// Carry arbitrary attributes:
	private var _attributes: TelemetryAttributes?

}
