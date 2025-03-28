import Foundation

public struct NautilusTelemetry {

	/// A single  queue for scheduled operations and coarse synchronization
	static let queue = DispatchQueue(label: "NautilusTelemetry", qos: .utility, attributes: [], autoreleaseFrequency: .workItem)
}
