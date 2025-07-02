// Created by Jon Parise on 6/20/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

// MARK: - URLTemplateMatcher

/// Matches URLs against a collection of URL template patterns.
///
/// Template patterns describe a URL path and query string. They can use
/// templated parameters like {} or {id} to match dynamic portions of the
/// path and query parameter values (e.g. "/users/{id}?status={status}").
///
/// Templates are matched in the order they are given. You should therefore
/// prioritize more-specific and more-likely-to-match template patterns.
///
/// ## Template Syntax
///
/// - Path parameters: `/users/{userId}`
/// - Query parameters: `?status={status}`
/// - Literal query values: `?status=active`
/// - Mixed: `/users/{id}?status={status}&verified=true`
///
/// ## Query Parameters
///
/// Query parameters can appear in any order to match. Any query parameters
/// that aren't named in the template are ignored.
///
/// If a literal query parameter pair (e.g. "status=active") is included in
/// the template, it must appear exactly that way in the URL for it to match.
///
/// ## Examples
///
/// Initialize a matcher with a list of templates. This should be done once
/// and then reused.
/// ```swift
/// let matcher = try URLTemplateMatcher(templates: [
///     "/users/{id}",
///     "/posts/{postId}/comments/{commentId}",
///     "/search?q={}&status=active"
/// ])
/// ```
///
/// Attempt to match a URL with one of our templates:
/// ```swift
/// let url = URL(string: "https://api.example.com/users/123")!
/// let matchedTemplate = matcher.match(url: url) // Returns "/users/{id}"
/// ```
///
/// Attempt to match a URL template when starting a Span:
/// ```swift
/// let span = tracer.startSpan(
///     request: request,
///     template: matcher.match(request.url)
/// )
/// ```
public struct URLTemplateMatcher {

	// MARK: Lifecycle

	/// Creates a matcher with the given URL templates.
	/// - Parameter templates: Array of URL template strings
	/// - Throws: If any template contains invalid syntax
	public init(templates: [StaticString]) throws {
		self.templates = try templates.map {
			let template = $0.withUTF8Buffer {
				String(decoding: $0, as: UTF8.self)
			}
			return try URLTemplate(template: template)
		}
	}

	/// Creates a matcher with the given URL templates.
	///
	/// If any of the templates contains invalid syntax, the initializer
	/// returns `nil`.
	///
	/// - Parameter templates: Array of URL template strings
	public init?(_ templates: [StaticString]) {
		try? self.init(templates: templates)
	}

	// MARK: Public

	/// Returns the template string of the first template that matches the URL.
	/// - Parameter url: The URL to match
	/// - Returns: The matching template string, or nil if no templates match
	public func match(url: URL?) -> String? {
		guard let url else { return nil }
		return templates.first { $0.matches(url: url) }?.template
	}

	// MARK: Private

	private let templates: [URLTemplate]
}

// MARK: - URLTemplate

/// A URL template pattern that can match against URL paths and query parameters.
struct URLTemplate {

	// MARK: Lifecycle

	init(template: String) throws {
		self.template = template

		// Split template into path and query components
		let components = template[...].split(separator: "?", maxSplits: 1)
		let pathTemplate = components[0]
		let queryTemplate = components.count > 1 ? components[1] : nil

		// Build the path-matching regex
		let pathPattern = pathTemplate.replacing(Self.parameterRegex, with: "[^/?]+")
		pathRegex = try Regex(String(pathPattern))

		// Parse any required query parameters from the template
		if let queryTemplate {
			(
				requiredTemplatedParameters,
				requiredLiteralParameters
			) = Self.parseRequiredParameters(from: queryTemplate)
		} else {
			requiredTemplatedParameters = []
			requiredLiteralParameters = [:]
		}
	}

	// MARK: Internal

	let template: String

	func matches(url: URL) -> Bool {
		// Check that the full path matches
		guard (try? pathRegex.wholeMatch(in: url.path())) != nil else {
			return false
		}

		// Check query parameters if any are required
		if hasRequiredParameters {
			guard let query = url.query() else {
				return false
			}

			let queryParameters = Dictionary(
				parseQueryStringPairs(from: query[...]),
				uniquingKeysWith: { first, _ in first }
			)

			// Check that all required templated parameters are present
			for templatedParam in requiredTemplatedParameters {
				guard queryParameters[templatedParam] != nil else {
					return false
				}
			}

			// Check that all required literal parameter pairs match exactly
			for (name, requiredValue) in requiredLiteralParameters {
				guard queryParameters[name] == requiredValue else {
					return false
				}
			}
		}

		return true
	}

	// MARK: Private

	/// Regex for matching parameters like {} and {id} in both path and query
	private static let parameterRegex = /\{[a-zA-Z0-9-_]*\}/

	private let pathRegex: Regex<Substring>
	private let requiredTemplatedParameters: Set<Substring>
	private let requiredLiteralParameters: [Substring: Substring]

	private var hasRequiredParameters: Bool {
		!requiredTemplatedParameters.isEmpty || !requiredLiteralParameters.isEmpty
	}

	/// Extracts templated and literal parameter pairs from a query template string.
	private static func parseRequiredParameters(from queryTemplate: Substring)
		-> (templated: Set<Substring>, literal: [Substring: Substring])
	{
		var templatedParams: Set<Substring> = []
		var literalParams: [Substring: Substring] = [:]

		for (name, value) in parseQueryStringPairs(from: queryTemplate) {
			if (try? parameterRegex.wholeMatch(in: value)) != nil {
				templatedParams.insert(name)
			} else {
				literalParams[name] = value
			}
		}

		return (templated: templatedParams, literal: literalParams)
	}
}

/// Extracts the list of (name, value) pairs from a URL query string.
private func parseQueryStringPairs(from query: Substring) -> [(Substring, Substring)] {
	query
		.split(separator: "&")
		.compactMap { pair in
			guard let equalIndex = pair.firstIndex(of: "=") else { return nil }
			return (
				pair.prefix(upTo: equalIndex),
				pair.suffix(from: pair.index(after: equalIndex))
			)
		}
}
