import Foundation

extension Bundle {
    public var appName: String { getInfo("CFBundleName")  }
    public var displayName: String {getInfo("CFBundleDisplayName")}
    public var language: String {getInfo("CFBundleDevelopmentRegion")}
    public var identifier: String {getInfo("CFBundleIdentifier")}

    public var appBuild: String { getInfo("CFBundleVersion") }
    public var appVersionLong: String { getInfo("CFBundleShortVersionString") }
    public var appVersionShort: String { getInfo("CFBundleShortVersion") }

    fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
}
