//
//  URLParseStrategy.swift
//
//
//  Created by Ladd Van Tol on 7/1/25.
//

import Foundation
import XCTest

extension XCTestCase {
	
	func makeURL(_ string: String) throws -> URL {
		try TestUtils.makeURL(string)
	}
}
