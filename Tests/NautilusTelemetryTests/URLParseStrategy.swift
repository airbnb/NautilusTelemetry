//
//  URLParseStrategy.swift
//
//
//  Created by Ladd Van Tol on 7/1/25.
//

import Foundation

let strategy = URL.ParseStrategy(
	scheme: .defaultValue("https"),
	user: .optional,
	password: .optional,
	host: .defaultValue("example.com"),
	port: .optional,
	path: .required,
	query: .optional,
	fragment: .optional)
