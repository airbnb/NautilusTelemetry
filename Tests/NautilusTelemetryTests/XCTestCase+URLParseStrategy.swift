//
//  URLParseStrategy.swift
//
//
//  Created by Ladd Van Tol on 7/1/25.
//

import Foundation
import XCTest

extension XCTestCase {
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

	func makeURL(_ string: String) throws -> URL {
		try Self.urlStrategy.parse(string)
	}
}
