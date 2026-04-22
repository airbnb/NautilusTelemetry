// Created by Ladd Van Tol on 4/21/26.
// Copyright © 2026 Airbnb Inc. All rights reserved.

class Weak<T: AnyObject> {

	// MARK: Lifecycle

	init(_ value: T) {
		self.value = value
	}

	// MARK: Internal

	weak var value: T?
}
