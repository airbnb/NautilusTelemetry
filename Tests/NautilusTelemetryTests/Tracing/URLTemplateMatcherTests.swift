// Created by Jon Parise on 6/20/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import XCTest

@testable import NautilusTelemetry

final class URLTemplateMatcherTests: XCTestCase {

	// MARK: - Path Matching Tests

	func testSimplePathMatching() throws {
		let matcher = try URLTemplateMatcher(templates: ["/users/{id}"])

		XCTAssertEqual(matcher.match(url: try makeURL("/users/123")), "/users/{id}")
		XCTAssertEqual(matcher.match(url: try makeURL("/users/abc")), "/users/{id}")
		XCTAssertNil(matcher.match(url: try makeURL("/posts/123")))
		XCTAssertNil(matcher.match(url: try makeURL("/users")))
	}

	func testMultiplePathParameters() throws {
		let matcher = try URLTemplateMatcher(templates: ["/posts/{postId}/comments/{commentId}"])

		XCTAssertEqual(
			matcher.match(url: try makeURL("/posts/123/comments/456")),
			"/posts/{postId}/comments/{commentId}"
		)
		XCTAssertNil(matcher.match(url: try makeURL("/posts/123/comments")))
		XCTAssertNil(matcher.match(url: try makeURL("/posts/123")))
	}

	func testLiteralPathMatching() throws {
		let matcher = try URLTemplateMatcher(templates: ["/api/v1/users"])

		XCTAssertEqual(matcher.match(url: try makeURL("/api/v1/users")), "/api/v1/users")
		XCTAssertNil(matcher.match(url: try makeURL("/api/v2/users")))
	}

	// MARK: - Query Parameter Tests

	func testTemplatedQueryParameters() throws {
		let matcher = try URLTemplateMatcher(templates: ["/search?q={query}"])

		XCTAssertEqual(
			matcher.match(url: try makeURL("/search?q=test")),
			"/search?q={query}"
		)
		XCTAssertEqual(
			matcher.match(url: try makeURL("/search?q=test&other=value")),
			"/search?q={query}"
		)
		XCTAssertNil(matcher.match(url: try makeURL("/search")))
		XCTAssertNil(matcher.match(url: try makeURL("/search?other=value")))
	}

	func testLiteralQueryParameters() throws {
		let matcher = try URLTemplateMatcher(templates: ["/users?status=active"])

		XCTAssertEqual(
			matcher.match(url: try makeURL("/users?status=active")),
			"/users?status=active"
		)
		XCTAssertEqual(
			matcher.match(url: try makeURL("/users?status=active&other=value")),
			"/users?status=active"
		)
		XCTAssertNil(matcher.match(url: try makeURL("/users?status=inactive")))
		XCTAssertNil(matcher.match(url: try makeURL("/users")))
	}

	func testMixedQueryParameters() throws {
		let matcher = try URLTemplateMatcher(templates: ["/users?status={status}&verified=true"])

		XCTAssertEqual(
			matcher.match(url: try makeURL("/users?status=active&verified=true")),
			"/users?status={status}&verified=true"
		)
		XCTAssertEqual(
			matcher.match(url: try makeURL("/users?verified=true&status=inactive")),
			"/users?status={status}&verified=true"
		)
		XCTAssertNil(matcher.match(url: try makeURL("/users?status=active&verified=false")))
		XCTAssertNil(matcher.match(url: try makeURL("/users?status=active")))
	}

	func testQueryParameterOrder() throws {
		let matcher = try URLTemplateMatcher(templates: ["/search?q={query}&sort={sort}"])

		XCTAssertEqual(
			matcher.match(url: try makeURL("/search?q=test&sort=date")),
			"/search?q={query}&sort={sort}"
		)
		XCTAssertEqual(
			matcher.match(url: try makeURL("/search?sort=date&q=test")),
			"/search?q={query}&sort={sort}"
		)
	}

	// MARK: - Complex Template Tests

	func testPathWithQueryParameters() throws {
		let matcher = try URLTemplateMatcher(templates: ["/users/{id}?include={fields}"])

		XCTAssertEqual(
			matcher.match(url: try makeURL("/users/123?include=profile")),
			"/users/{id}?include={fields}"
		)
		XCTAssertNil(matcher.match(url: try makeURL("/users/123")))
		XCTAssertNil(matcher.match(url: try makeURL("/posts/123?include=profile")))
	}

	// MARK: - Multiple Template Tests

	func testMultipleTemplates() throws {
		let matcher = try URLTemplateMatcher(templates: [
			"/users/{id}",
			"/posts/{id}",
			"/search?q={query}",
		])

		XCTAssertEqual(matcher.match(url: try makeURL("/users/123")), "/users/{id}")
		XCTAssertEqual(matcher.match(url: try makeURL("/posts/456")), "/posts/{id}")
		XCTAssertEqual(matcher.match(url: try makeURL("/search?q=test")), "/search?q={query}")
		XCTAssertNil(matcher.match(url: try makeURL("/comments/789")))
	}

	func testMultipleMatchingTemplates() throws {
		let matcher = try URLTemplateMatcher(templates: [
			"/api/{version}/users",
			"/api/v1/users",
		])

		// Should match the first template since it's more general
		XCTAssertEqual(
			matcher.match(url: try makeURL("/api/v1/users")),
			"/api/{version}/users"
		)
	}

	// MARK: - Edge Cases

	func testEmptyTemplates() throws {
		let matcher = try URLTemplateMatcher(templates: [])
		XCTAssertNil(matcher.match(url: try makeURL("/users/123")))
	}

	func testNilURL() throws {
		let matcher = try URLTemplateMatcher(templates: ["/users/{id}"])
		XCTAssertNil(matcher.match(url: nil))
	}

	func testURLWithoutQuery() throws {
		let matcher = try URLTemplateMatcher(templates: ["/users/{id}"])
		XCTAssertEqual(matcher.match(url: try makeURL("/users/123")), "/users/{id}")
	}

	func testURLWithEmptyQuery() throws {
		let matcher = try URLTemplateMatcher(templates: ["/users/{id}"])
		XCTAssertEqual(matcher.match(url: try makeURL("/users/123?")), "/users/{id}")
	}

	func testAnonymousParameters() throws {
		let matcher = try URLTemplateMatcher(templates: [
			"/users/{}",
			"/posts/{id}/{}",
			"/search?q={}",
		])

		XCTAssertEqual(matcher.match(url: try makeURL("/users/123")), "/users/{}")
		XCTAssertEqual(matcher.match(url: try makeURL("/posts/456/title")), "/posts/{id}/{}")
		XCTAssertEqual(matcher.match(url: try makeURL("/search?q=test")), "/search?q={}")
	}

	func testSpecialCharactersInParameters() throws {
		let matcher = try URLTemplateMatcher(templates: ["/users/{user_id}", "/posts/{post-id}"])

		XCTAssertEqual(matcher.match(url: try makeURL("/users/123")), "/users/{user_id}")
		XCTAssertEqual(matcher.match(url: try makeURL("/posts/456")), "/posts/{post-id}")
	}

	func testRootPath() throws {
		let matcher = try URLTemplateMatcher(templates: ["/"])
		XCTAssertEqual(matcher.match(url: try makeURL("/")), "/")
		XCTAssertNil(matcher.match(url: try makeURL("/users")))
	}

	func testPathWithSlashes() throws {
		let matcher = try URLTemplateMatcher(templates: ["/api/v1/{resource}"])

		XCTAssertEqual(matcher.match(url: try makeURL("/api/v1/users")), "/api/v1/{resource}")
		// Path parameters shouldn't match slashes
		XCTAssertNil(matcher.match(url: try makeURL("/api/v1/users/123")))
	}

	func testDuplicateQueryParameters() throws {
		let matcher = try URLTemplateMatcher(templates: ["/search?q={query}"])

		XCTAssertEqual(
			matcher.match(url: try makeURL("/search?q=first&q=second")),
			"/search?q={query}"
		)
	}

}

