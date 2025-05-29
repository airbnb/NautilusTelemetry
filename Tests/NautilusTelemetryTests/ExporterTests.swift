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
		
		let string = "abc"
		let stringVal = try XCTUnwrap(exporter.convertToOTLP(value: string))
		XCTAssertEqual(stringVal.stringValue, "abc")
	}

	func testConvertToOTLPBool() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		let bool1 = true
		let boolVal1 = try XCTUnwrap(exporter.convertToOTLP(value: bool1))
		XCTAssertEqual(boolVal1.boolValue, true)

		let bool2 = false
		let boolVal2 = try XCTUnwrap(exporter.convertToOTLP(value: bool2))
		XCTAssertEqual(boolVal2.boolValue, false)
	}
	
	func testConvertToOTLPFloats() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		let float = Float(100)
		let floatValue = try XCTUnwrap(exporter.convertToOTLP(value: float))
		XCTAssertEqual(Float(try XCTUnwrap(floatValue.doubleValue)), float)

		let double = Double(32)
		let doubleValue = try XCTUnwrap(exporter.convertToOTLP(value: double))
		XCTAssertEqual(doubleValue.doubleValue, double)
	}
	
	func testConvertToOTLPIntegers() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		let uint64 = UInt64.max
		let intValue1 = try XCTUnwrap(exporter.convertToOTLP(value: uint64))
		XCTAssertEqual(try XCTUnwrap(intValue1.intValue as? UInt64), uint64)

		let int64 = Int64.max
		let intValue2 = try XCTUnwrap(exporter.convertToOTLP(value: int64))
		XCTAssertEqual(try XCTUnwrap(intValue2.intValue as? Int64), int64)

		let uint32 = UInt32.max
		let intValue3 = try XCTUnwrap(exporter.convertToOTLP(value: uint32))
		XCTAssertEqual(try XCTUnwrap(intValue3.intValue as? UInt32), uint32)

		// make sure we don't cast to Bool accidentally
		let uint: UInt = 0
		let intValue4 = try XCTUnwrap(exporter.convertToOTLP(value: uint))
		XCTAssertEqual(try XCTUnwrap(intValue4.intValue as? UInt), uint)
		XCTAssertNil(intValue4.boolValue)

		let int32 = Int32.max
		let intValue5 = try XCTUnwrap(exporter.convertToOTLP(value: int32))
		XCTAssertEqual(try XCTUnwrap(intValue5.intValue as? Int32), int32)
	}

	func testJSONEncoding() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)

		// Check a normal case
		do {
			let normalAnyValue = try XCTUnwrap(exporter.convertToOTLP(value: 0))
			let encoded = try JSONEncoder().encode(normalAnyValue)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":0}"#)
		}

		// Check that ints in the bound are expressed as JSON numbers
		do {
			let lowerIntBound = -(1 << 53)
			let lowerIntBoundAnyValue = try XCTUnwrap(exporter.convertToOTLP(value: lowerIntBound))
			let encoded = try JSONEncoder().encode(lowerIntBoundAnyValue)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":-9007199254740992}"#)
		}

		do {
			let upperIntBound = (1 << 53)
			let upperIntBoundAnyIntValue = try XCTUnwrap(exporter.convertToOTLP(value: upperIntBound))
			let encoded = try JSONEncoder().encode(upperIntBoundAnyIntValue)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":9007199254740992}"#)
		}

		// Check that ints outside the bound are expressed as JSON strings
		do {
			let lowerIntBound = -(1 << 53)-1
			let lowerIntBoundAnyValue = try XCTUnwrap(exporter.convertToOTLP(value: lowerIntBound))
			let encoded = try JSONEncoder().encode(lowerIntBoundAnyValue)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":"-9007199254740993"}"#)
		}

		do {
			let upperIntBound = (1 << 53)+1
			let upperIntBoundAnyIntValue = try XCTUnwrap(exporter.convertToOTLP(value: upperIntBound))
			let encoded = try JSONEncoder().encode(upperIntBoundAnyIntValue)
			let encodedString = String(data: encoded, encoding: .utf8)
			XCTAssertEqual(encodedString, #"{"intValue":"9007199254740993"}"#)
		}

		// Check Int128 support
		// The GitHub CI machine runs macOS 14.5, but I need a compile time check
//		do {
//			if #available(iOS 18.0, macOS 15.0, *) {
//				let upperIntBound = Int128.max
//				let upperIntBoundAnyIntValue = try XCTUnwrap(exporter.convertToOTLP(value: upperIntBound))
//				let encoded = try JSONEncoder().encode(upperIntBoundAnyIntValue)
//				let encodedString = String(data: encoded, encoding: .utf8)
//				XCTAssertEqual(encodedString, #"{"intValue":"170141183460469231731687303715884105727"}"#)
//			}
//		}
	}

	func testConvertToOTLPComplexTypes() throws {
		let exporter = Exporter(timeReference: timeReference, prettyPrint: false)
		let data = try XCTUnwrap("📀".data(using: .utf8))
		let dataValue = try XCTUnwrap(exporter.convertToOTLP(value: data))
		XCTAssertEqual(dataValue.bytesValue, data)
		let encodedJsonString = String(data: try exporter.encodeJSON(dataValue), encoding: .utf8)
		XCTAssertEqual(encodedJsonString, #"{"bytesValue":"f09f9380"}"#)
		
		let array: [Any] = ["foo", 1]
		let arrayValue = try XCTUnwrap(exporter.convertToOTLP(value: array))
		let values = try XCTUnwrap(arrayValue.arrayValue?.values)
		let value0 = values[0]
		XCTAssertEqual("foo", value0.stringValue)
		let value1 = values[1]
		XCTAssertEqual(1, value1.intValue as? Int)

		let dictionary = ["foo": 1]
		let dictionaryValue = try XCTUnwrap(exporter.convertToOTLP(value: dictionary))
		let kvValue = try XCTUnwrap(dictionaryValue.kvlistValue?.values?[0])
		XCTAssertEqual(kvValue.key, "foo")
		XCTAssertEqual(kvValue.value?.intValue as? Int, 1)

		let notConvertible = self
		let notConvertibleValue = exporter.convertToOTLP(value: notConvertible)
		XCTAssertNil(notConvertibleValue)
	}
}

