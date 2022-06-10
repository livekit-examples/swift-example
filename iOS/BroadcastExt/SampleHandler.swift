//
//  SampleHandler.swift
//  LiveKitExample
//
//  Created by David Liu on 6/9/22.
//

import Foundation
import LiveKit
class SampleHandler : LKSampleHandler {
    
    override func appGroupIdentifier() -> String {
        return "group.io.livekit.example.SwiftSDK.1"
    }
}
