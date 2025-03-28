//
//  Compression.swift
//  
//
//  Created by Van Tol, Ladd on 10/11/21.
//

import Foundation
import Compression
import zlib

/// Implements simple one-shot compressors for telemetry payloads
/// Maybe worth using a more complete implementation such as: https://github.com/mw99/DataCompression
/// Unfortunately, Apple doesn't let you control compression level
public struct Compression {
	
	enum CompressionError: Error {
		case failure
	}

	public static func compressDeflate(data: Data) throws -> Data {
		let compressed = try compress(source: data, algorithm: .zlib)

		// Now stick on the header and adler to make it deflate format
		var output = Data([0x78, 0x5e])
		output.append(compressed)
		var adler = adler32_zlib(data).bigEndian
		output.append(Data(bytes: &adler, count: MemoryLayout<UInt32>.size))
		
		return output
	}

	@available(iOS 15.0, *)
	public static func compressBrotli(data: Data) throws -> Data {
		return try compress(source: data, algorithm: .brotli)
	}

	static func adler32_zlib(_ data: Data) -> UInt32 {
		data.withUnsafeBytes {
			UInt32(zlib.adler32(1, $0.baseAddress, UInt32($0.count)))
		}
	}

	// https://developer.apple.com/documentation/Accelerate/compressing-and-decompressing-data-with-input-and-output-filters
	private static func compress(source: Data, algorithm: Algorithm) throws -> Data {
		var compressedData = Data()

		let outputFilter = try OutputFilter(.compress, using: algorithm) {
			(data: Data?) -> Void in
			if let data = data {
				compressedData.append(data)
			}
		}

		try outputFilter.write(source)
		try outputFilter.finalize()

		return compressedData
	}
}
