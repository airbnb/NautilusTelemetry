//
//  Sampler.swift
//
//
//  Created by Ladd Van Tol on 1/12/22.
//

import CryptoKit
import Foundation
import os

// MARK: - Sampler

public protocol Sampler {
	var shouldSample: Bool { get }
}

// MARK: - StableGuidSampler

/// A sampler that is stable for a given GUID.
/// Intended to be used for session-based sampling or similar use cases.
public final class StableGuidSampler: Sampler {

	// MARK: Lifecycle

	/// Initialize a sampler that uses.
	/// - Parameters:
	///   - sampleRate: Rate of sampling, as a percentage [0...100].
	///   - guid: A GUID to sample (current session, device id, user id or similar identifier).
	///   - seed: A seed. All samplers sharing the same seed will produce the same results. May be empty.
	public init(sampleRate: Double, seed: Data, guid: Data) {
		self.sampleRate = sampleRate
		self.seed = seed
		_guid = guid
		shouldSample = false
		computeShouldSample()
	}

	// MARK: Public

	public private(set) var shouldSample: Bool

	/// A rate of sampling, expressed as a percentage [0...100].
	public var sampleRate: Double {
		didSet {
			assert(sampleRate >= 0 && sampleRate <= 100, "expected to be in 0-100 range")
			if oldValue != sampleRate {
				computeShouldSample()
			}
		}
	}

	/// At least 1 byte of random guid data. This can be set when the underlying guid changes.
	public var guid: Data {
		// actors would be great here!
		get {
			lock.withLock { _guid }
		}

		set {
			assert(newValue.count >= 0, "expected at least 1 byte of data")

			var didChange = false
			lock.withLockUnchecked {
				if newValue != _guid {
					_guid = newValue
					didChange = true
				}
			}

			if didChange {
				computeShouldSample()
			}
		}
	}

	// MARK: Internal

	/// A seed to allow multiple orthogonal samples to be taken from the same GUID.
	let seed: Data

	func computeShouldSample() {
		var hash = SHA256()
		hash.update(data: seed)
		hash.update(data: guid)
		let hashResult = Data(hash.finalize())

		let neededByteCount = MemoryLayout<UInt32>.size
		guard hashResult.count > neededByteCount else {
			assert(false, "expected at least \(neededByteCount) bytes")
			return
		}

		let val = hashResult.withUnsafeBytes { $0.load(as: UInt32.self) }
		let sessionRampVal = Double(val) / Double(UInt32.max) * 100.0
		shouldSample = sessionRampVal <= sampleRate
	}

	// MARK: Private

	private let lock = OSAllocatedUnfairLock()

	private var _guid: Data

}
