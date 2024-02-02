/*
 * Copyright 2024 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import LiveKit
import Logging
import OSLog

private let broadcastLogger = OSLog(subsystem: "io.livekit.example.SwiftSDK", category: "Broadcast")
class SampleHandler: LKSampleHandler {
    override public init() {
        // Turn on logging for the Broadcast Extension
        LoggingSystem.bootstrap { label in
            var logHandler = LoggingOSLog(label: label, log: broadcastLogger)
            logHandler.logLevel = .debug
            return logHandler
        }
    }
}
