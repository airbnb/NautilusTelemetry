//
//  ProcessDetails.swift
//
//
//  Created by Ladd Van Tol on 9/23/21.
//

import Foundation

/// Provides information about the running process
public enum ProcessDetails {

	/// Provide the elapsed time since the process started.
	public static var timeSinceStart: Duration {
		let now = Date.timeIntervalBetween1970AndReferenceDate + Date.timeIntervalSinceReferenceDate

		var kp = kinfo_proc()
		var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
		var len = MemoryLayout.size(ofValue: kp)

		return mib.withUnsafeMutableBufferPointer { mib in
			guard sysctl(mib.baseAddress, 4, &kp, &len, nil, 0) == 0, len > 0 else {
				perror("sysctl")
				return .zero
			}
			let startTime = kp.kp_proc.p_starttime
			let processLaunchTime = Double(startTime.tv_sec) + (Double(startTime.tv_usec) / 1_000_000.0)
			return Duration.seconds(now - processLaunchTime)
		}
	}
}
