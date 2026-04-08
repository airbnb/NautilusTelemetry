// Created by Ladd Van Tol on 3/13/26.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import CoreTelephony
import Foundation
import Network
import Synchronization

// MARK: - NetworkMonitor

public final class NetworkMonitor {

	// MARK: Lifecycle

	public init() { }

	// MARK: Public

	public var attributes: TelemetryAttributes {
		var attributes = TelemetryAttributes()

		if let networkPath = networkPath.withLock({ $0 }) {
			attributes["network.path.status"] = networkPath.status.description
			if networkPath.status == .unsatisfied {
				attributes["network.path.unsatisfied_reason"] = networkPath.unsatisfiedReason.description
			}

			if #available(iOS 26.0, macOS 26.0, *) {
				attributes["network.path.link_quality"] = networkPath.linkQuality.description
			}
		}

		#if os(iOS)
		if
			let dataServiceIdentifier = telephonyNetworkInfo.dataServiceIdentifier,
			let serviceCurrentRadioAccessTechnology = telephonyNetworkInfo.serviceCurrentRadioAccessTechnology,
			let radioAccessTechnology = serviceCurrentRadioAccessTechnology[dataServiceIdentifier]
		{
			attributes["network.connection.subtype"] = radioAccessTechnologyDescription(radioAccessTechnology)
		}
		#endif

		return attributes
	}

	public func start() {
		pathMonitor.pathUpdateHandler = { [weak self] path in
			self?.networkPath.withLock { $0 = path }
		}
		pathMonitor.start(queue: pathMonitorQueue)
	}

	public func stop() {
		pathMonitor.cancel()
		networkPath.withLock { $0 = nil }
	}

	// MARK: Internal

	#if os(iOS)
	func radioAccessTechnologyDescription(_ technology: String) -> String {
		radioAccessTechnologyMap[technology] ?? technology
	}
	#endif

	// MARK: Private

	private let pathMonitor = NWPathMonitor(prohibitedInterfaceTypes: [.loopback])
	private let pathMonitorQueue = DispatchQueue(label: "com.airbnb.nautilustelemetry.pathmonitor", qos: .utility)
	private let networkPath = Mutex<NWPath?>(nil)

	#if os(iOS)
	private let telephonyNetworkInfo = CTTelephonyNetworkInfo()

	private let radioAccessTechnologyMap: [String: String] = [
		CTRadioAccessTechnologyGPRS: "GPRS",
		CTRadioAccessTechnologyEdge: "Edge",
		CTRadioAccessTechnologyWCDMA: "WCDMA",
		CTRadioAccessTechnologyHSDPA: "HSDPA",
		CTRadioAccessTechnologyHSUPA: "HSUPA",
		CTRadioAccessTechnologyCDMA1x: "CDMA1x",
		CTRadioAccessTechnologyCDMAEVDORev0: "CDMAEVDORev0",
		CTRadioAccessTechnologyCDMAEVDORevA: "CDMAEVDORevA",
		CTRadioAccessTechnologyCDMAEVDORevB: "CDMAEVDORevB",
		CTRadioAccessTechnologyeHRPD: "eHRPD",
		CTRadioAccessTechnologyLTE: "LTE",
		CTRadioAccessTechnologyNRNSA: "NRNSA",
		CTRadioAccessTechnologyNR: "NR",
	]
	#endif
}

// MARK: - NWPath.Status + @retroactive CustomStringConvertible

extension NWPath.Status: @retroactive CustomStringConvertible {
	public var description: String {
		switch self {
		case .satisfied:
			"satisfied"
		case .unsatisfied:
			"unsatisfied"
		case .requiresConnection:
			"requiresConnection"
		@unknown default:
			"unknown"
		}
	}
}

// MARK: - NWPath.LinkQuality + @retroactive CustomStringConvertible

@available(iOS 26.0, macOS 26.0, *)
extension NWPath.LinkQuality: @retroactive CustomStringConvertible {
	public var description: String {
		switch self {
		case .good:
			"good"
		case .moderate:
			"moderate"
		case .minimal:
			"minimal"
		case .unknown:
			"unknown"
		@unknown default:
			"unknown"
		}
	}
}

// MARK: - NWPath.UnsatisfiedReason + @retroactive CustomStringConvertible

extension NWPath.UnsatisfiedReason: @retroactive CustomStringConvertible {
	public var description: String {
		switch self {
		case .notAvailable:
			"notAvailable"
		case .cellularDenied:
			"cellularDenied"
		case .wifiDenied:
			"wifiDenied"
		case .localNetworkDenied:
			"localNetworkDenied"
		case .vpnInactive:
			"vpnInactive"
		@unknown default:
			"unknown"
		}
	}
}
