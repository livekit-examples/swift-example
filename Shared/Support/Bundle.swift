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

public extension Bundle {
    var appName: String { getInfo("CFBundleName") }
    var displayName: String { getInfo("CFBundleDisplayName") }
    var language: String { getInfo("CFBundleDevelopmentRegion") }
    var identifier: String { getInfo("CFBundleIdentifier") }

    var appBuild: String { getInfo("CFBundleVersion") }
    var appVersionLong: String { getInfo("CFBundleShortVersionString") }
    var appVersionShort: String { getInfo("CFBundleShortVersion") }

    private func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
}
