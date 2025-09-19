//
//  XCTestCase+Leaks
//
//
//  Created by Ladd Van Tol on 4/7/25.
//

import XCTest

extension XCTestCase {
	func trackForMemoryLeak(
		instance: AnyObject,
		file: StaticString = #filePath,
		line: UInt = #line
	) {
		addTeardownBlock { [weak instance] in
			XCTAssertNil(
				instance,
				"potential memory leak on \(String(describing: instance))",
				file: file,
				line: line
			)
		}
	}
}
