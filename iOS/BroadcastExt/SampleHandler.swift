//
//  NewSampleHandler.swift
//  BroadcastExt
//
//  Created by David Liu on 6/15/22.
//

import Foundation
import LiveKit
import Logging
import OSLog

fileprivate let broadcastLogger = OSLog(subsystem: "io.livekit.example.SwiftSDK", category: "Broadcast")
class SampleHandler : LKSampleHandler {
    
    public override init() {
        // Turn on logging for the Broadcast Extension
        LoggingSystem.bootstrap({ label in
            var logHandler = LoggingOSLog(label: label, log: broadcastLogger)
            logHandler.logLevel = .debug
            return logHandler
        })
    }
}
