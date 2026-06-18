//
//  Baggage.swift
//
//
//  Created by Van Tol, Ladd on 11/15/21.
//

import Foundation
import Synchronization

// MARK: - SubtraceLinking

public struct SubtraceLinking: OptionSet, Sendable {

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

public final class Baggage: TelemetryAttributesContainer, Sendable {

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
		// Infer baggage attributes from current context if not provided
		lockedAttributes = Mutex(attributes ?? Baggage.currentBaggageTaskLocal?.attributes)
	}

	// MARK: Public

	/// The parent span this baggage is attached to.
	public let span: Span

	/// Vend private attributes as a thread-safe copy
	public var attributes: TelemetryAttributes? {
		lockedAttributes.withLock { $0 }
	}

	/// Adds an attribute to the baggage. This can be used to propagate selected attributes to child spans.
	/// https://opentelemetry.io/docs/concepts/signals/baggage/#baggage-is-not-the-same-as-attributes
	/// - Parameters:
	///   - name: a name, conforming to https://github.com/open-telemetry/opentelemetry-specification/tree/main/specification/trace/semantic_conventions
	///   - value: a value.
	public func addAttribute(_ name: String, _ value: AttributeValue?) {
		guard let value else { return }

		lockedAttributes.withLock { attributes in
			if attributes == nil {
				attributes = TelemetryAttributes()
			}

			attributes?[name] = value
		}
	}

	public subscript(name: String) -> AttributeValue? {
		get {
			lockedAttributes.withLock { $0?[name] }
		}
		set(newValue) {
			addAttribute(name, newValue)
		}
	}

	// MARK: Internal

	/// TaskLocal works even for conventional threads: https://developer.apple.com/documentation/swift/tasklocal
	@TaskLocal static var currentBaggageTaskLocal: Baggage?

	let subTraceId: TraceId?
	let subtraceLinking: SubtraceLinking

	// MARK: Private

	/// Carry arbitrary attributes, guarded for thread-safe access:
	private let lockedAttributes: Mutex<TelemetryAttributes?>

}
