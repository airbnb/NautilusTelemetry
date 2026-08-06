//
//  Numeric.swift
//
//
//  Created by Ladd Van Tol on 8/6/26.
//

import Foundation

public typealias MetricNumeric = Comparable & Numeric

/// False for a floating-point NaN or infinity, which would poison an instrument's `sum` and range, and
/// fail JSON encoding at export time. Integer types have no non-finite representation and always pass.
///
/// `MetricNumeric` is a composition of standard protocols rather than a protocol of our own, so finiteness
/// has to be recovered at runtime. This is on the `record`/`add` hot path, so the type is tested by metatype
/// rather than by casting the value: the comparisons fold away once the generic is specialized, leaving
/// `Counter<Int>.add` unchanged, where a `value as? Double` cast measured ≈20 ns per call.
/// `Double` and `Float` are the only floating-point types the exporter can convert, per `asDouble`.
@inline(__always)
func isFiniteMetricValue<T: MetricNumeric>(_ value: T) -> Bool {
	if T.self == Double.self {
		(value as! Double).isFinite
	} else if T.self == Float.self {
		(value as! Float).isFinite
	} else {
		true
	}
}
