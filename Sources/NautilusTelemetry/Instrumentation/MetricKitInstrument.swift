//
//  MetricKitInstrument.swift
//  
//
//  Created by Ladd Van Tol on 10/12/21.
//

import Foundation

#if canImport(MetricKit) && os(iOS)
import MetricKit

public final class MetricKitInstrument: NSObject, MXMetricManagerSubscriber {
	
	// https://developer.apple.com/documentation/metrickit/mxmetricmanager

	func start() {
		let metricManager = MXMetricManager.shared
		metricManager.add(self)
		
		let customMetricLogger = MXMetricManager.makeLogHandle(category: "testOTLPExporterMetrics")
		
		os_signpost(.begin, log: customMetricLogger, name: "test")
		Thread.sleep(forTimeInterval: 0.1)
		os_signpost(.end, log: customMetricLogger, name: "test")

		if #available(iOS 14.0, *) {
			let pastPayloads = metricManager.pastPayloads
			
			if pastPayloads.count > 0 {
				logger.debug("MetricKitInstrument: \(pastPayloads)")
			}
		
			let diagnosticPayloads = metricManager.pastDiagnosticPayloads
			if diagnosticPayloads.count > 0 {
				logger.debug("MetricKitInstrument: \(diagnosticPayloads)")
			}
		}
	}
	
	public func didReceive(_ payloads: [MXMetricPayload]) {
		logger.debug("MetricKitInstrument: \(payloads)")
		
		for payload in payloads {
			let json = payload.jsonRepresentation() // try JSON representation
			if let jsonString = String(data: json, encoding: .utf8) {
				logger.debug("\(jsonString)")
			}
			
			dump(payload: payload)
		}
	}
	
	@available(iOS 14.0, *)
	public func didReceive(_ payloads: [MXDiagnosticPayload]) {
		logger.debug("MetricKitInstrument: \(payloads)")
		
		for payload in payloads {
			let json = payload.jsonRepresentation() // could pull this apart, but JSON representation may be most useful.
			if let jsonString = String(data: json, encoding: .utf8) {
				logger.debug("\(jsonString)")
			}
		}
	}
	
	func dump<UnitType>(histogram: MXHistogram<UnitType>) where UnitType : Unit {
		for bucket in histogram.bucketEnumerator {
			if let bucket = bucket as? MXHistogramBucket<UnitType> {
				logger.debug("\(bucket.bucketStart)-\(bucket.bucketEnd): \(bucket.bucketCount)")
			}
		}
	}
	
	func dump(payload: MXMetricPayload) {
		logger.debug("latestApplicationVersion: \(payload.latestApplicationVersion)")
		logger.debug("timeStampBegin: \(payload.timeStampBegin)")
		logger.debug("timeStampEnd: \(payload.timeStampEnd)")

		if let cpuMetrics = payload.cpuMetrics {
			logger.debug("cpuMetrics: \(cpuMetrics)")
		}

		if let gpuMetrics = payload.gpuMetrics {
			logger.debug("gpuMetrics: \(gpuMetrics)")
		}

		if let cellularConditionMetrics = payload.cellularConditionMetrics {
			logger.debug("cellularConditionMetrics: \(cellularConditionMetrics)")
			dump(histogram: cellularConditionMetrics.histogrammedCellularConditionTime)
		}

		if let applicationTimeMetrics = payload.applicationTimeMetrics {
			logger.debug("applicationTimeMetrics: \(applicationTimeMetrics)")
		}

		if let locationActivityMetrics = payload.locationActivityMetrics {
			logger.debug("locationActivityMetrics: \(locationActivityMetrics)")
		}

		if let networkTransferMetrics = payload.networkTransferMetrics {
			logger.debug("networkTransferMetrics: \(networkTransferMetrics)")
		}

		if let applicationLaunchMetrics = payload.applicationLaunchMetrics {
			logger.debug("applicationLaunchMetrics: \(applicationLaunchMetrics)")
			dump(histogram: applicationLaunchMetrics.histogrammedTimeToFirstDraw)
			dump(histogram: applicationLaunchMetrics.histogrammedApplicationResumeTime)

		}

		if let applicationResponsivenessMetrics = payload.applicationResponsivenessMetrics {
			logger.debug("applicationResponsivenessMetrics: \(applicationResponsivenessMetrics)")
			dump(histogram: applicationResponsivenessMetrics.histogrammedApplicationHangTime)
		}

		if let diskIOMetrics = payload.diskIOMetrics {
			logger.debug("diskIOMetrics: \(diskIOMetrics)")
		}

		if let memoryMetrics = payload.memoryMetrics {
			logger.debug("memoryMetrics: \(memoryMetrics)")
		}

		if let displayMetrics = payload.displayMetrics {
			logger.debug("displayMetrics: \(displayMetrics)")
		}

		if #available(iOS 14.0, *) {
			if let animationMetrics = payload.animationMetrics {
				logger.debug("animationMetrics: \(animationMetrics)")
			}

			if let applicationExitMetrics = payload.applicationExitMetrics {
				logger.debug("applicationExitMetrics: \(applicationExitMetrics)")
			}
		}
		
		if let signpostMetrics = payload.signpostMetrics {
			logger.debug("signpostMetrics: \(signpostMetrics)")
		}

		if let metaData = payload.metaData {
			logger.debug("metaData: \(metaData)")
		}
	}
}
#endif // canImport

