//
//  ExporterTests.swift
//
//
//  Created by Ladd Van Tol on 3/22/22.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class ExporterTests: XCTestCase {
	let timeReference = TimeReference(serverOffset: 0)

	func testConvertToOTLPString() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		let value = exporter.convertToOTLP(value: .string("abc"))
		XCTAssertEqual(value.stringValue, "abc")
	}

	func testConvertToOTLPBool() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		XCTAssertEqual(exporter.convertToOTLP(value: .bool(true)).boolValue, true)
		XCTAssertEqual(exporter.convertToOTLP(value: .bool(false)).boolValue, false)
	}

	func testConvertToOTLPDouble() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		// `AttributeValue` always stores floating-point values as `Double`.
		let value = exporter.convertToOTLP(value: AttributeValue(Float(100)))
		XCTAssertEqual(Float(try XCTUnwrap(value.doubleValue)), 100)

		XCTAssertEqual(exporter.convertToOTLP(value: .double(32)).doubleValue, 32)
	}

	func testConvertToOTLPIntegers() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		// AttributeValue normalizes integers to `Int64`. Very large `UInt64` values
		// that exceed `Int64.max` will be bit-equivalent but interpreted as negative.
		let int64 = Int64.max
		XCTAssertEqual(exporter.convertToOTLP(value: .int(int64)).intValue, int64)

		XCTAssertEqual(exporter.convertToOTLP(value: AttributeValue(UInt32.max)).intValue, Int64(UInt32.max))
		XCTAssertEqual(exporter.convertToOTLP(value: AttributeValue(Int32.max)).intValue, Int64(Int32.max))
		XCTAssertEqual(exporter.convertToOTLP(value: AttributeValue(UInt(0))).intValue, 0)
	}

	func testJSONEncoding() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		// Check a normal case
		do {
			let normalAnyValue = exporter.convertToOTLP(value: .int(0))
			let encoded = try JSONEncoder().encode(normalAnyValue)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":0}"#)
		}

		// Check that ints in the bound are expressed as JSON numbers
		do {
			let lowerIntBound: Int64 = -(1 << 53)
			let v = exporter.convertToOTLP(value: .int(lowerIntBound))
			let encoded = try JSONEncoder().encode(v)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":-9007199254740992}"#)
		}

		do {
			let upperIntBound: Int64 = (1 << 53)
			let v = exporter.convertToOTLP(value: .int(upperIntBound))
			let encoded = try JSONEncoder().encode(v)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":9007199254740992}"#)
		}

		// Check that ints outside the bound are expressed as JSON strings
		do {
			let lowerIntBound: Int64 = -(1 << 53) - 1
			let v = exporter.convertToOTLP(value: .int(lowerIntBound))
			let encoded = try JSONEncoder().encode(v)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":"-9007199254740993"}"#)
		}

		do {
			let upperIntBound: Int64 = (1 << 53) + 1
			let v = exporter.convertToOTLP(value: .int(upperIntBound))
			let encoded = try JSONEncoder().encode(v)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":"9007199254740993"}"#)
		}
	}

	func testConvertToOTLPComplexTypes() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)
		let data = try XCTUnwrap("📀".data(using: .utf8))
		let dataValue = exporter.convertToOTLP(value: .data(data))
		XCTAssertEqual(dataValue.bytesValue, data)
		let encodedJsonString = String(data: try exporter.encodeJSON(dataValue), encoding: .utf8)
		XCTAssertEqual(encodedJsonString, #"{"bytesValue":"f09f9380"}"#)

		let array: AttributeValue = [.string("foo"), .int(1)]
		let arrayValue = exporter.convertToOTLP(value: array)
		let values = try XCTUnwrap(arrayValue.arrayValue?.values)
		XCTAssertEqual(values[0].stringValue, "foo")
		XCTAssertEqual(values[1].intValue, 1)

		let dictionary: AttributeValue = ["foo": .int(1)]
		let dictionaryValue = exporter.convertToOTLP(value: dictionary)
		let kvValue = try XCTUnwrap(dictionaryValue.kvlistValue?.values?.first { $0.key == "foo" })
		XCTAssertEqual(kvValue.value?.intValue, 1)
	}

	func testAsDoubleHelper() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		// Test Double conversion
		let doubleValue = 42.5
		XCTAssertEqual(exporter.asDouble(doubleValue), 42.5)

		// Test Int conversion
		let intValue = 100
		XCTAssertEqual(exporter.asDouble(intValue), 100.0)
	}

	func testAsIntStringHelper() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		// Test Int conversion
		let intValue = 42
		XCTAssertEqual(exporter.asIntString(intValue), "42")

		// Test negative Int
		let negativeIntValue: Int = -100
		XCTAssertEqual(exporter.asIntString(negativeIntValue), "-100")

		// Test that Double returns nil (not supported by asIntString)
		let doubleValue = 42.5
		XCTAssertNil(exporter.asIntString(doubleValue))
	}

	func testConvertToOTLPExplicitBounds() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		// Test with Int bounds
		let intBounds = [10, 20, 30]
		let convertedIntBounds = exporter.convertToOTLP(explicitBounds: intBounds)
		XCTAssertEqual(convertedIntBounds, [10.0, 20.0, 30.0])

		// Test with Double bounds
		let doubleBounds = [10.5, 20.5, 30.5]
		let convertedDoubleBounds = exporter.convertToOTLP(explicitBounds: doubleBounds)
		XCTAssertEqual(convertedDoubleBounds, [10.5, 20.5, 30.5])

		// Test empty bounds
		let emptyBounds = [Int]()
		let convertedEmptyBounds = exporter.convertToOTLP(explicitBounds: emptyBounds)
		XCTAssertEqual(convertedEmptyBounds, [])
	}

	func testConvertToOTLPAttributes() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		// Test nil attributes returns nil
		XCTAssertNil(exporter.convertToOTLP(attributes: nil))

		// Test sorting by key
		let attributes: TelemetryAttributes = [
			"zebra": "last",
			"apple": "first",
			"middle": 123,
		]

		let result = try XCTUnwrap(exporter.convertToOTLP(attributes: attributes))

		// Verify sorting
		XCTAssertEqual(result.count, 3)
		XCTAssertEqual(result[0].key, "apple")
		XCTAssertEqual(result[0].value?.stringValue, "first")
		XCTAssertEqual(result[1].key, "middle")
		XCTAssertEqual(result[1].value?.intValue, 123)
		XCTAssertEqual(result[2].key, "zebra")
		XCTAssertEqual(result[2].value?.stringValue, "last")
	}
}
