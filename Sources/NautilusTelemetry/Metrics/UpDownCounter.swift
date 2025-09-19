//
//  UpDownCounter.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation

public class UpDownCounter<T: MetricNumeric>: Counter<T> {
	override public var isMonotonic: Bool { false }

	/// May be negative.
	override public func add(_ number: T, attributes: TelemetryAttributes = [:]) {
		super.add(number, attributes: attributes)
	}
}
