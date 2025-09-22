//
//  SnapshotAndResetTests.swift
//
//
//  Created by Claude Code on 9/16/25.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class SnapshotAndResetTests: XCTestCase {

	let unit = Unit(symbol: "bytes")

	// MARK: - Counter Tests

	func testCounterSnapshotAndReset() throws {
		let counter = Counter<Int>(name: "TestCounter", unit: unit, description: "Test counter")

		// Add some values
		counter.add(100, attributes: ["key1": "value1"])
		counter.add(200, attributes: ["key2": "value2"])

		// Verify counter has values
		XCTAssertFalse(counter.values.values.isEmpty)
		XCTAssertEqual(counter.values.values.count, 2)

		let originalStartTime = counter.startTime

		// Perform snapshot and reset
		let snapshot = counter.snapshotAndReset()

		// Verify snapshot properties
		XCTAssertEqual(snapshot.name, "TestCounter")
		XCTAssertEqual(snapshot.unit?.symbol, "bytes")
		XCTAssertEqual(snapshot.description, "Test counter")
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		XCTAssertEqual(snapshot.aggregationTemporality, .delta)

		// Verify snapshot has the original values
		guard let snapshotCounter = snapshot as? Counter<Int> else {
			XCTFail("Snapshot should be Counter<Int>")
			return
		}
		XCTAssertEqual(snapshotCounter.values.values.count, 2)
		XCTAssertTrue(snapshotCounter.values.values.contains { attributes, value in
			value == 100 && attributes["key1"] as? String == "value1"
		})
		XCTAssertTrue(snapshotCounter.values.values.contains { attributes, value in
			value == 200 && attributes["key2"] as? String == "value2"
		})

		// Verify original counter is reset
		XCTAssertTrue(counter.values.values.isEmpty)
		XCTAssertNil(counter.endTime)
		XCTAssertGreaterThan(counter.startTime, originalStartTime)
	}

	func testCounterSnapshotAndResetEmptyCounter() throws {
		let counter = Counter<Int>(name: "EmptyCounter", unit: unit, description: "Empty test counter")

		let originalStartTime = counter.startTime

		// Perform snapshot and reset on empty counter
		let snapshot = counter.snapshotAndReset()

		// Verify snapshot properties
		XCTAssertEqual(snapshot.name, "EmptyCounter")
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)

		// Verify snapshot has no values
		guard let snapshotCounter = snapshot as? Counter<Int> else {
			XCTFail("Snapshot should be Counter<Int>")
			return
		}
		XCTAssertTrue(snapshotCounter.values.values.isEmpty)

		// Verify original counter remains empty but has updated start time
		XCTAssertTrue(counter.values.values.isEmpty)
		XCTAssertGreaterThan(counter.startTime, originalStartTime)
	}

	// MARK: - UpDownCounter Tests

	func testUpDownCounterSnapshotAndReset() throws {
		let counter = UpDownCounter<Int>(name: "TestUpDownCounter", unit: unit, description: "Test up-down counter")

		// Add positive and negative values with different attributes
		counter.add(100, attributes: ["operation": "add1"])
		counter.add(-50, attributes: ["operation": "subtract"])
		counter.add(25, attributes: ["operation": "add2"])

		// Verify counter has values
		XCTAssertFalse(counter.values.values.isEmpty)
		XCTAssertEqual(counter.values.values.count, 3)

		let originalStartTime = counter.startTime

		// Perform snapshot and reset
		let snapshot = counter.snapshotAndReset()

		// Verify snapshot properties
		XCTAssertEqual(snapshot.name, "TestUpDownCounter")
		XCTAssertEqual(snapshot.unit?.symbol, "bytes")
		XCTAssertEqual(snapshot.description, "Test up-down counter")
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		// Verify it's an UpDownCounter (which is not monotonic)
		guard let snapshotUpDownCounter = snapshot as? UpDownCounter<Int> else {
			XCTFail("Snapshot should be UpDownCounter<Int>")
			return
		}
		XCTAssertFalse(snapshotUpDownCounter.isMonotonic)

		// Verify snapshot has the original values
		guard let snapshotCounter = snapshot as? UpDownCounter<Int> else {
			XCTFail("Snapshot should be UpDownCounter<Int>")
			return
		}
		XCTAssertEqual(snapshotCounter.values.values.count, 3)

		// Verify original counter is reset
		XCTAssertTrue(counter.values.values.isEmpty)
		XCTAssertNil(counter.endTime)
		XCTAssertGreaterThan(counter.startTime, originalStartTime)
	}

	// MARK: - Histogram Tests

	func testHistogramSnapshotAndReset() throws {
		let explicitBounds: [Int] = [10, 50, 100, 500]
		let histogram = Histogram<Int>(name: "TestHistogram", unit: unit, description: "Test histogram", explicitBounds: explicitBounds)

		// Record some values
		histogram.record(5, attributes: ["bucket": "small"])
		histogram.record(75, attributes: ["bucket": "medium"])
		histogram.record(250, attributes: ["bucket": "large"])

		// Verify histogram has values
		XCTAssertFalse(histogram.values.values.isEmpty)

		let originalStartTime = histogram.startTime

		// Perform snapshot and reset
		let snapshot = histogram.snapshotAndReset()

		// Verify snapshot properties
		XCTAssertEqual(snapshot.name, "TestHistogram")
		XCTAssertEqual(snapshot.unit?.symbol, "bytes")
		XCTAssertEqual(snapshot.description, "Test histogram")
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		XCTAssertEqual(snapshot.aggregationTemporality, .delta)

		// Verify snapshot has the original values
		guard let snapshotHistogram = snapshot as? Histogram<Int> else {
			XCTFail("Snapshot should be Histogram<Int>")
			return
		}
		XCTAssertFalse(snapshotHistogram.values.values.isEmpty)
		XCTAssertEqual(snapshotHistogram.values.explicitBounds, explicitBounds)

		// Verify original histogram is reset
		XCTAssertTrue(histogram.values.values.isEmpty)
		XCTAssertNil(histogram.endTime)
		XCTAssertGreaterThan(histogram.startTime, originalStartTime)
	}

	// MARK: - ObservableCounter Tests

	func testObservableCounterSnapshotAndReset() throws {
		var callbackInvoked = false
		let counter = ObservableCounter<Int>(
			name: "TestObservableCounter",
			unit: unit,
			description: "Test observable counter"
		) { counter in
			callbackInvoked = true
			counter.observe(500, attributes: ["source": "callback"])
		}

		let originalStartTime = counter.startTime

		// Perform snapshot and reset
		let snapshot = counter.snapshotAndReset()

		// Verify callback was invoked during snapshot
		XCTAssertTrue(callbackInvoked)

		// Verify snapshot properties
		XCTAssertEqual(snapshot.name, "TestObservableCounter")
		XCTAssertEqual(snapshot.unit?.symbol, "bytes")
		XCTAssertEqual(snapshot.description, "Test observable counter")
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		XCTAssertEqual(snapshot.aggregationTemporality, .delta)

		// Verify snapshot has the callback-observed values
		guard let snapshotCounter = snapshot as? ObservableCounter<Int> else {
			XCTFail("Snapshot should be ObservableCounter<Int>")
			return
		}
		XCTAssertFalse(snapshotCounter.values.values.isEmpty)
		XCTAssertTrue(snapshotCounter.values.values.contains { attributes, value in
			value == 500 && attributes["source"] as? String == "callback"
		})

		// Verify original counter is reset
		XCTAssertTrue(counter.values.values.isEmpty)
		XCTAssertNil(counter.endTime)
		XCTAssertGreaterThan(counter.startTime, originalStartTime)
	}

	func testObservableCounterSnapshotAndResetMultipleObservations() throws {
		let counter = ObservableCounter<Int>(
			name: "TestMultiObservableCounter",
			unit: unit,
			description: "Test multi-observation counter"
		) { counter in
			counter.observe(100, attributes: ["type": "first"])
			counter.observe(200, attributes: ["type": "second"])
			counter.observe(300, attributes: ["type": "third"])
		}

		// Perform snapshot and reset
		let snapshot = counter.snapshotAndReset()

		// Verify snapshot has all observed values
		guard let snapshotCounter = snapshot as? ObservableCounter<Int> else {
			XCTFail("Snapshot should be ObservableCounter<Int>")
			return
		}
		XCTAssertEqual(snapshotCounter.values.values.count, 3)
	}

	// MARK: - ObservableUpDownCounter Tests

	func testObservableUpDownCounterSnapshotAndReset() throws {
		var callbackInvoked = false
		let counter = ObservableUpDownCounter<Int>(
			name: "TestObservableUpDownCounter",
			unit: unit,
			description: "Test observable up-down counter"
		) { counter in
			callbackInvoked = true
			counter.observe(-100, attributes: ["direction": "down"])
			counter.observe(150, attributes: ["direction": "up"])
		}

		let originalStartTime = counter.startTime

		// Perform snapshot and reset
		let snapshot = counter.snapshotAndReset()

		// Verify callback was invoked during snapshot
		XCTAssertTrue(callbackInvoked)

		// Verify snapshot properties
		XCTAssertEqual(snapshot.name, "TestObservableUpDownCounter")
		XCTAssertEqual(snapshot.unit?.symbol, "bytes")
		XCTAssertEqual(snapshot.description, "Test observable up-down counter")
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		XCTAssertEqual(snapshot.aggregationTemporality, .delta)

		// Verify snapshot has the callback-observed values
		guard let snapshotCounter = snapshot as? ObservableUpDownCounter<Int> else {
			XCTFail("Snapshot should be ObservableUpDownCounter<Int>")
			return
		}
		XCTAssertEqual(snapshotCounter.values.values.count, 2)

		// Verify original counter is reset
		XCTAssertTrue(counter.values.values.isEmpty)
		XCTAssertNil(counter.endTime)
		XCTAssertGreaterThan(counter.startTime, originalStartTime)
	}

	// MARK: - ObservableGauge Tests

	func testObservableGaugeSnapshotAndReset() throws {
		var callbackInvoked = false
		let gauge = ObservableGauge<Int>(name: "TestObservableGauge", unit: unit, description: "Test observable gauge") { gauge in
			callbackInvoked = true
			gauge.observe(750, attributes: ["measurement": "current"])
		}

		let originalStartTime = gauge.startTime

		// Perform snapshot and reset
		let snapshot = gauge.snapshotAndReset()

		// Verify callback was invoked during snapshot
		XCTAssertTrue(callbackInvoked)

		// Verify snapshot properties
		XCTAssertEqual(snapshot.name, "TestObservableGauge")
		XCTAssertEqual(snapshot.unit?.symbol, "bytes")
		XCTAssertEqual(snapshot.description, "Test observable gauge")
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		XCTAssertEqual(snapshot.aggregationTemporality, .unspecified) // Gauge uses unspecified

		// Verify snapshot has the callback-observed values
		guard let snapshotGauge = snapshot as? ObservableGauge<Int> else {
			XCTFail("Snapshot should be ObservableGauge<Int>")
			return
		}
		XCTAssertFalse(snapshotGauge.values.values.isEmpty)
		XCTAssertTrue(snapshotGauge.values.values.contains { attributes, value in
			value == 750 && attributes["measurement"] as? String == "current"
		})

		// Verify original gauge is reset
		XCTAssertTrue(gauge.values.values.isEmpty)
		XCTAssertNil(gauge.endTime)
		XCTAssertGreaterThan(gauge.startTime, originalStartTime)
	}

	// MARK: - Thread Safety Tests

	func testCounterSnapshotAndResetThreadSafety() throws {
		let counter = Counter<Int>(name: "ConcurrentCounter", unit: unit, description: "Concurrent test counter")
		let expectation = XCTestExpectation(description: "Concurrent operations complete")
		expectation.expectedFulfillmentCount = 10

		// Perform concurrent adds and snapshots
		for i in 0..<10 {
			DispatchQueue.global().async {
				if i % 2 == 0 {
					counter.add(100)
				} else {
					_ = counter.snapshotAndReset()
				}
				expectation.fulfill()
			}
		}

		wait(for: [expectation], timeout: 5.0)

		// Test passes if no crashes occur
		XCTAssertTrue(true)
	}

	func testHistogramSnapshotAndResetThreadSafety() throws {
		let histogram = Histogram<Int>(
			name: "ConcurrentHistogram",
			unit: unit,
			description: "Concurrent test histogram",
			explicitBounds: [10, 100, 1000]
		)
		let expectation = XCTestExpectation(description: "Concurrent operations complete")
		expectation.expectedFulfillmentCount = 10

		// Perform concurrent records and snapshots
		for i in 0..<10 {
			DispatchQueue.global().async {
				if i % 2 == 0 {
					histogram.record(50)
				} else {
					_ = histogram.snapshotAndReset()
				}
				expectation.fulfill()
			}
		}

		wait(for: [expectation], timeout: 5.0)

		// Test passes if no crashes occur
		XCTAssertTrue(true)
	}

	// MARK: - Edge Cases

	func testSnapshotAndResetPreservesMetadata() throws {
		let counter = Counter<Double>(name: "MetadataCounter", unit: Unit(symbol: "ms"), description: "Counter with metadata")
		counter.aggregationTemporality = .cumulative

		counter.add(1.5, attributes: ["precision": "high"])

		let snapshot = counter.snapshotAndReset()

		// Verify all metadata is preserved
		XCTAssertEqual(snapshot.name, "MetadataCounter")
		XCTAssertEqual(snapshot.unit?.symbol, "ms")
		XCTAssertEqual(snapshot.description, "Counter with metadata")
		XCTAssertEqual(snapshot.aggregationTemporality, .cumulative)

		guard let snapshotCounter = snapshot as? Counter<Double> else {
			XCTFail("Snapshot should be Counter<Double>")
			return
		}
		XCTAssertTrue(snapshotCounter.values.values.contains { attributes, value in
			value == 1.5 && attributes["precision"] as? String == "high"
		})
	}

	func testMultipleConsecutiveSnapshotAndReset() throws {
		let counter = Counter<Int>(name: "MultiSnapshotCounter", unit: unit, description: "Multiple snapshot counter")

		// First round
		counter.add(100)
		let snapshot1 = counter.snapshotAndReset()
		let startTime1 = counter.startTime

		// Second round
		counter.add(200)
		let snapshot2 = counter.snapshotAndReset()
		let startTime2 = counter.startTime

		// Third round
		counter.add(300)
		let snapshot3 = counter.snapshotAndReset()

		// Verify each snapshot has correct values and timing
		guard
			let snap1 = snapshot1 as? Counter<Int>,
			let snap2 = snapshot2 as? Counter<Int>,
			let snap3 = snapshot3 as? Counter<Int>
		else {
			XCTFail("All snapshots should be Counter<Int>")
			return
		}

		XCTAssertTrue(snap1.values.values.contains { _, value in value == 100 })
		XCTAssertTrue(snap2.values.values.contains { _, value in value == 200 })
		XCTAssertTrue(snap3.values.values.contains { _, value in value == 300 })

		// Verify timing progression
		XCTAssertGreaterThan(startTime1, snap1.startTime)
		XCTAssertGreaterThan(startTime2, startTime1)
		XCTAssertGreaterThan(counter.startTime, startTime2)

		// Verify counter is empty after all operations
		XCTAssertTrue(counter.values.values.isEmpty)
	}
}
