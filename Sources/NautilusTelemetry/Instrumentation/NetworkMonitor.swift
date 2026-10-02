// Created by Ladd Van Tol on 3/13/26.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import CoreTelephony
import Foundation
import Network
import Synchronization

// MARK: - NetworkMonitor

public final class NetworkMonitor {

	// MARK: Lifecycle

	public init() {
		#if os(iOS)
		telephonyNetworkInfoFactory = { CTTelephonyNetworkInfo() }
		#endif
	}

	#if os(iOS)
	init(telephonyNetworkInfoFactory: @escaping () -> CTTelephonyNetworkInfo) {
		self.telephonyNetworkInfoFactory = telephonyNetworkInfoFactory
	}
	#endif

	// MARK: Public

	public var attributes: TelemetryAttributes {
		var attributes = TelemetryAttributes()
		let currentPath = networkPath.withLock { $0 }

		if let networkPath = currentPath {
			attributes["network.path.status"] = .string(networkPath.status.description)
			if networkPath.status == .unsatisfied {
				attributes["network.path.unsatisfied_reason"] = .string(networkPath.unsatisfiedReason.description)
			}

			if #available(iOS 26.0, macOS 26.0, *) {
				attributes["network.path.link_quality"] = .string(networkPath.linkQuality.description)
			}
		}

		#if os(iOS)
		// CoreTelephony can synchronously contact CommCenter; only read it for cellular paths.
		if
			let telephonyNetworkInfo = cellularNetworkInfo(usesCellularInterface: currentPath?.usesInterfaceType(.cellular)),
			let dataServiceIdentifier = telephonyNetworkInfo.dataServiceIdentifier,
			let serviceCurrentRadioAccessTechnology = telephonyNetworkInfo.serviceCurrentRadioAccessTechnology,
			let radioAccessTechnology = serviceCurrentRadioAccessTechnology[dataServiceIdentifier]
		{
			attributes["network.connection.subtype"] = .string(radioAccessTechnologyDescription(radioAccessTechnology))
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
	func cellularNetworkInfo(usesCellularInterface: Bool) -> CTTelephonyNetworkInfo? {
		guard usesCellularInterface else { return nil }
		return telephonyNetworkInfo.withLock { networkInfo in
			if let networkInfo { return networkInfo }
			let createdNetworkInfo = telephonyNetworkInfoFactory()
			networkInfo = createdNetworkInfo
			return createdNetworkInfo
		}
	}

	func radioAccessTechnologyDescription(_ technology: String) -> String {
		radioAccessTechnologyMap[technology] ?? technology
	}
	#endif

	// MARK: Private

	private let pathMonitor = NWPathMonitor(prohibitedInterfaceTypes: [.loopback])
	private let pathMonitorQueue = DispatchQueue(label: "com.airbnb.nautilustelemetry.pathmonitor", qos: .utility)
	private let networkPath = Mutex<NWPath?>(nil)

	#if os(iOS)
	private let telephonyNetworkInfo = Mutex<CTTelephonyNetworkInfo?>(nil)
	private let telephonyNetworkInfoFactory: () -> CTTelephonyNetworkInfo

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
