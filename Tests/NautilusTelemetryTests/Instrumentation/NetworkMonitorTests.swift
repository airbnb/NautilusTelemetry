// Created by ladd_vantol on 03/13/26.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import CoreTelephony
import Network
import Testing

@testable import NautilusTelemetry

// MARK: - NWPathStatusTests

struct NWPathStatusTests {

	@Test
	func `all status descriptions are distinct`() {
		let descriptions = [NWPath.Status.satisfied, .unsatisfied, .requiresConnection].map(\.description)
		#expect(Set(descriptions).count == descriptions.count)
	}
}

// MARK: - NWPathUnsatisfiedReasonTests

struct NWPathUnsatisfiedReasonTests {

	@Test
	func `all unsatisfied reason descriptions are distinct`() {
		let descriptions = [
			NWPath.UnsatisfiedReason.notAvailable,
			.cellularDenied,
			.wifiDenied,
			.localNetworkDenied,
			.vpnInactive,
		].map(\.description)
		#expect(Set(descriptions).count == descriptions.count)
	}
}

// MARK: - NWPathLinkQualityTests

struct NWPathLinkQualityTests {

	@Test
	func `all link quality descriptions are distinct`() {
		if #available(iOS 26.0, macOS 26.0, *) {
			let descriptions = [NWPath.LinkQuality.good, .moderate, .minimal, .unknown].map(\.description)
			#expect(Set(descriptions).count == descriptions.count)
		}
	}
}

// MARK: - NautilusTelemetryNetworkMonitorTests

#if os(iOS)
struct NautilusTelemetryNetworkMonitorTests {

	// MARK: Internal

	@Test
	func `unknown radio access technology returns the raw string`() {
		#expect(monitor.radioAccessTechnologyDescription("SomeFutureTechnology") == "SomeFutureTechnology")
	}

	@Test
	func `known radio access technology constant maps to its short name`() {
		#expect(monitor.radioAccessTechnologyDescription(CTRadioAccessTechnologyLTE) == "LTE")
	}

	@Test
	func `all known radio access technology constants map to distinct short names`() {
		let constants = [
			CTRadioAccessTechnologyGPRS,
			CTRadioAccessTechnologyEdge,
			CTRadioAccessTechnologyWCDMA,
			CTRadioAccessTechnologyHSDPA,
			CTRadioAccessTechnologyHSUPA,
			CTRadioAccessTechnologyCDMA1x,
			CTRadioAccessTechnologyCDMAEVDORev0,
			CTRadioAccessTechnologyCDMAEVDORevA,
			CTRadioAccessTechnologyCDMAEVDORevB,
			CTRadioAccessTechnologyeHRPD,
			CTRadioAccessTechnologyLTE,
			CTRadioAccessTechnologyNRNSA,
			CTRadioAccessTechnologyNR,
		]
		let descriptions = constants.map { monitor.radioAccessTechnologyDescription($0) }
		#expect(Set(descriptions).count == descriptions.count)
	}

	// MARK: Private

	private let monitor = NetworkMonitor()

}

#endif
