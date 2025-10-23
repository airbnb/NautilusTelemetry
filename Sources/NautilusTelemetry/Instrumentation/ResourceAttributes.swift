//
//  ResourceAttributes.swift
//
//
//  Created by Van Tol, Ladd on 11/4/21.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - ResourceAttributes

/// Defines top-level
public struct ResourceAttributes {

	// MARK: Lifecycle

	public init(
		bundleIdentifier: String,
		applicationVersion: String,
		vendorIdentifier: String,
		deviceModelIdentifier: String,
		osType: String = "darwin",
		osName: String = defaultOSName,
		osVersion: String,
		additionalAttributes: TelemetryAttributes?
	) {
		self.bundleIdentifier = bundleIdentifier
		self.applicationVersion = applicationVersion
		self.vendorIdentifier = vendorIdentifier
		self.deviceModelIdentifier = deviceModelIdentifier
		self.osType = osType
		self.osName = osName
		self.osVersion = osVersion
		self.additionalAttributes = additionalAttributes
	}

	// MARK: Public

	#if os(macOS)
	public static let defaultOSName = "macOS"
	#elseif os(iOS)
	public static let defaultOSName = "iOS"
	#else
	public static let defaultOSName = "unknown"
	#endif

	/// Create a default set of resource attributes.
	/// - Parameter additionalAttributes: Additional attributes, that may override existing attributes. Must conform to https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/common/attribute-naming.md
	/// - Returns: Built attributes.
	public static func makeWithDefaults(additionalAttributes: TelemetryAttributes?) -> ResourceAttributes {
		let placeholder = "unknown"

		let bundle = Bundle.main
		let bundleIdentifier = bundle.bundleIdentifier ?? placeholder
		let applicationVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? placeholder

		#if canImport(UIKit) && os(iOS)
		let vendorIdentifier = UIDevice.current.identifierForVendor?.uuidString ?? placeholder
		#else
		let vendorIdentifier = placeholder
		#endif

		let model = HardwareDetails.platformCachedValue ?? placeholder

		return ResourceAttributes(
			bundleIdentifier: bundleIdentifier,
			applicationVersion: applicationVersion,
			vendorIdentifier: vendorIdentifier,
			deviceModelIdentifier: model,
			osVersion: osVersion,
			additionalAttributes: additionalAttributes
		)
	}

	// MARK: Internal

	static var osVersion: String {
		let osv = ProcessInfo.processInfo.operatingSystemVersion
		if osv.patchVersion > 0 {
			return "\(osv.majorVersion).\(osv.minorVersion).\(osv.patchVersion)"
		} else {
			return "\(osv.majorVersion).\(osv.minorVersion)"
		}
	}

	let bundleIdentifier: String
	let applicationVersion: String

	let vendorIdentifier: String
	let deviceModelIdentifier: String

	let osType: String
	let osName: String
	let osVersion: String
	let additionalAttributes: TelemetryAttributes?

	var keyValues: TelemetryAttributes {
		// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/common/common.md

		var attributes = TelemetryAttributes()

		// https://opentelemetry.io/docs/specs/semconv/registry/attributes/service/
		attributes["service.name"] = "\(osName.lowercased()).app"
		attributes["service.namespace"] = bundleIdentifier
		attributes["service.version"] = applicationVersion
		attributes["telemetry.sdk.name"] = "NautilusTelemetry"
		attributes["telemetry.sdk.language"] = "swift"
		attributes["device.id"] = vendorIdentifier
		// Can we set "deployment.environment" here?

		// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/resource/semantic_conventions/device.md
		attributes["device.manufacturer"] = "Apple"
		attributes["device.model"] = deviceModelIdentifier

		// https://opentelemetry.io/docs/specs/semconv/resource/os/
		attributes["os.type"] = osType
		attributes["os.name"] = osName
		attributes["os.version"] = osVersion

		if let additionalAttributes {
			// Overwrite any existing keys.
			attributes.merge(additionalAttributes) { _, new in new }
		}

		return attributes
	}
}
