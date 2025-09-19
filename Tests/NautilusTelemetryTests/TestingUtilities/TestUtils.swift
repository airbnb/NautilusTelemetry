// Created by Ladd Van Tol on 9/15/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Compression
import Foundation
import OSLog
import XCTest

@testable import NautilusTelemetry

enum TestUtils {

	enum UtilError: Error {
		case unexpectedNil
		case environmentMissing
	}

	static let logger = Logger(subsystem: "NautilusTelemetry", category: "TestUtils")

	static let instrumentationScope = OTLP.V1InstrumentationScope(name: "NautilusTelemetry", version: "1.0")
	static let schemaUrl = "https://github.com/airbnb/NautilusTelemetry"

	static let urlStrategy = URL.ParseStrategy(
		scheme: .defaultValue("https"),
		user: .optional,
		password: .optional,
		host: .defaultValue("example.com"),
		port: .optional,
		path: .required,
		query: .optional,
		fragment: .optional
	)

	static var additionalAttributes: [String: String] {
		get throws {
			guard let env = ProcessInfo.processInfo.environment["additionalAttributes"] else { return [:] }

			var dictionary = [String: String]()

			let elements = env.split(separator: ",")

			for element in elements {
				let pair = element.split(separator: "=")
				if pair.count == 2 {
					dictionary[String(pair[0])] = String(pair[1])
				}
			}

			return dictionary
		}
	}

	static func testEnabled(_ name: String) -> Bool {
		if let val = ProcessInfo.processInfo.environment[name] {
			return Bool(val) ?? false
		}
		return false
	}

	static func endpoint(_ name: String) throws -> URL {
		if let val = ProcessInfo.processInfo.environment[name] {
			return try makeURL(val)
		}

		throw UtilError.unexpectedNil
	}

	static func makeURL(_ string: String) throws -> URL {
		try urlStrategy.parse(string)
	}

	static func encodeJSON(_ value: some Encodable) throws -> Data {
		let encoder = JSONEncoder()
		OTLP.configure(encoder: encoder) // setup hex
		// Forward slash escaping is only needed for HTML embedding.
		// Add pretty printing and sortedKeys for ease of reading test output
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		return try encoder.encode(value)
	}

	static func formattedHeaders(_ headers: [String: String]) -> String {
		var result = ""

		let keys = headers.keys.sorted()
		for key in keys {
			if let value = headers[key] {
				result.append("\(key): \(value)\n")
			}
		}

		return result
	}

	/// https://github.com/open-telemetry/opentelemetry-collector/blob/main/receiver/otlpreceiver/README.md
	static func postJSON(url: URL, json: Data, test: XCTestCase) throws {
		var urlRequest = URLRequest(url: url)

		urlRequest.httpMethod = "POST"
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
		urlRequest.setValue("\(json.count)", forHTTPHeaderField: "Content-Length")

		let compressedJSON = try Compression.compressDeflate(data: json)
		urlRequest.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
		urlRequest.httpBody = compressedJSON

		guard let allHeaderFields = urlRequest.allHTTPHeaderFields else { throw UtilError.unexpectedNil }
		let requestHeaders = formattedHeaders(allHeaderFields)

		logger.debug("\(urlRequest.httpMethod?.description ?? "nil") \(url.path)\n\(requestHeaders)")

		if let jsonString = String(data: json, encoding: .utf8) {
			logger.debug("\(jsonString)")
		}

		let completion = test.expectation(description: "postToLocalOpenTelemetryCollector")
		let task = URLSession.shared.dataTask(with: urlRequest) { data, response, _ in
			if let response = response as? HTTPURLResponse {
				XCTAssertEqual(response.statusCode, 200)

				let responseHeaders = formattedHeaders(response.allHeaderFields as! [String: String])
				logger.debug("Response:\n\(responseHeaders)")
			}

			if let data, let jsonString = String(data: data, encoding: .utf8) {
				logger.debug("\(jsonString)")
			}

			completion.fulfill()
		}

		task.resume()
		test.wait(for: [completion], timeout: 30)
	}
}
