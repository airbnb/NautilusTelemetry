// Created by Ladd Van Tol on 12/15/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

public enum Redaction {

	// MARK: Public

	/// Provides a default implementation of URL redaction that hides common sensitive elements.
	/// - Parameter url: A URL to redact
	/// - Returns: A string representing the URL with sensitive data redacted. Returns nil if the URL cannot be decomposed.
	static public func defaultUrlRedaction(_ url: URL) -> String? {
		guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }

		// https://opentelemetry.io/docs/specs/semconv/registry/attributes/url/#url-full

		if components.user != nil {
			components.user = Redaction.redacted
		}

		if components.password != nil {
			components.password = Redaction.redacted
		}

		if let queryItems = components.queryItems {
			// Redact AWS security parameters by default
			let prefixes: Set<String> = ["x-amz-"]
			components.queryItems = queryItems.map { queryItem in
				let queryItemName = queryItem.name.lowercased()
				if prefixes.contains(where: { queryItemName.hasPrefix($0) }) {
					return URLQueryItem(name: queryItem.name, value: Redaction.redacted)
				} else {
					return queryItem
				}
			}
		}

		return components.url?.absoluteString
	}

	// MARK: Internal

	static public let redacted = "REDACTED"
}
