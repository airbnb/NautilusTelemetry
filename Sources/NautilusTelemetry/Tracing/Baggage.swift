//
//  Baggage.swift
//  
//
//  Created by Van Tol, Ladd on 11/15/21.
//

import Foundation
import os

public final class Baggage: @unchecked Sendable {

  // TaskLocal works even for conventional threads: https://developer.apple.com/documentation/swift/tasklocal
	@TaskLocal static var currentBaggageTaskLocal: Baggage?
	
	public init(span: Span) {
		self.span = span
	}
	
	let span: Span
}
