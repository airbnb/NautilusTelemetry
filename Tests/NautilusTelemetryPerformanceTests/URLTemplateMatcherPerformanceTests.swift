//
//  URLTemplateMatcherPerformanceTests.swift
//
//
//  Created by Ladd Van Tol on 2026-04-20.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class URLTemplateMatcherPerformanceTests: XCTestCase {

	func testPerformance() throws {
		let url =
			try XCTUnwrap(
				URL(
					string: "https://api.example.com/v3/ExampleApi/b18eda0692022ab1d32d7e9e396eeb213578e79e29f9cbaf0f4b6f1403234f0a?extensions=%7B%22persistedQuery%22:%7B%22sha256Hash%22:%22b18eda0692022ab1d32d7e9e396eeb213578e79e29f9cbaf0f4b6f1403234f0a%22,%22version%22:1%7D%7D&operationName=AutoSuggestions&operationType=query&variables=%7B%22autoSuggestionsRequest%22:%7B%22rawParams%22:%5B%7B%22filterName%22:%22homepageExample%22,%22filterValues%22:%5B%22FOO%22%5D%7D%5D,%22source%22:%22HOMEPAGE%22,%22treatmentFlags%22:%5B%5D%7D%7D"
				)
			)

		let tracedURLTemplates = URLTemplateMatcher([
			"/v3/{target}/{identifier}",
			"/v2/{target}",
			"/v2/{target}/",
			"/v2/{target}/{}",
			"/v2/{target}/{}/{}",
		])

		let iterations = 1000

		measure {
			for _ in 0..<iterations {
				let template = tracedURLTemplates?.match(url: url)
				XCTAssertNotNil(template)
			}
		}
	}

}
