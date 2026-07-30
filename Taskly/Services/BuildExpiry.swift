//
//  BuildExpiry.swift
//  Taskly
//

import Foundation

/// When the signature on this build stops working. A free Apple developer account signs
/// apps for seven days, after which iOS refuses to launch them until they are rebuilt.
struct BuildExpiry: Sendable, Equatable {
    enum Source: Sendable, Equatable {
        /// Read straight out of the embedded provisioning profile.
        case provisioningProfile
        /// No profile to read, so it is inferred from when the binary was built.
        case buildDateEstimate
    }

    var expiresAt: Date
    var source: Source

    /// Whole days left, floored, so `1` means it dies at some point tomorrow.
    func daysRemaining(from now: Date = Date()) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: expiresAt)
        ).day ?? 0
    }

    func isExpired(at now: Date = Date()) -> Bool { expiresAt <= now }
}

@MainActor
enum BuildExpiryReader {
    /// How long a signature from a free Apple developer account lasts.
    static let freeAccountDays = 7

    /// Double optional so a resolved "there is no profile" result is still cached.
    private static var cached: BuildExpiry??

    /// Cached because it touches the file system and cannot change while the app runs.
    static func current() -> BuildExpiry? {
        if let cached { return cached }
        let resolved = resolve()
        cached = resolved
        return resolved
    }

    private static func resolve() -> BuildExpiry? {
        if let date = provisioningProfileExpiry() {
            return BuildExpiry(expiresAt: date, source: .provisioningProfile)
        }
        if let date = buildDateExpiry() {
            return BuildExpiry(expiresAt: date, source: .buildDateEstimate)
        }
        return nil
    }

    /// The profile is a CMS signed blob, but its payload plist sits inside as plain XML,
    /// so the expiry can be lifted out without decoding the signature.
    private static func provisioningProfileExpiry() -> Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)),
              start.lowerBound < end.upperBound
        else { return nil }

        let payload = data[start.lowerBound..<end.upperBound]
        let plist = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil)
        return (plist as? [String: Any])?["ExpirationDate"] as? Date
    }

    /// Simulator builds and App Store copies have no embedded profile, so fall back to the
    /// binary's timestamp and assume a free account's seven day window.
    private static func buildDateExpiry() -> Date? {
        guard let path = Bundle.main.executablePath,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let built = attributes[.modificationDate] as? Date
        else { return nil }
        return Calendar.current.date(byAdding: .day, value: freeAccountDays, to: built)
    }
}
