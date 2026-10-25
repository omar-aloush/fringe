import Foundation

/// Tiny lock-protected box for the series cache.
nonisolated final class NSLockWrapped<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T

    init(_ value: T) { self.value = value }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

/// A real, bundled GNSS position time series: daily IGS20 solutions from the
/// Nevada Geodetic Lab, downsampled to weekly means and referenced to the
/// first 30 days of the display window.
nonisolated struct GNSSSeries: Codable, Identifiable, Sendable {    let station: String
    let name: String
    let t0: String
    let source: String
    /// Each sample: [daysSinceT0, eastMm, northMm, upMm]
    let samples: [[Double]]

    var id: String { station }
    var lastSample: [Double]? { samples.last }
    var spanDays: Double { samples.last?[0] ?? 0 }

    /// Total 3D displacement from the reference epoch, in cm.
    var total3DCm: Double? {
        guard let s = lastSample, s.count >= 4 else { return nil }
        return (s[1] * s[1] + s[2] * s[2] + s[3] * s[3]).squareRoot() / 10
    }

    /// Loads every bundled series for an event, e.g. "kilauea" -> UWEV + AHUP.
    /// Results are cached: Event Detail re-renders every frame during the dance.
    nonisolated static func load(eventId: String) -> [GNSSSeries] {
        if let cached = Self.cache.withLock({ $0[eventId] }) { return cached }
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let series = urls
            .filter { $0.lastPathComponent.hasPrefix("\(eventId)-") }
            .compactMap { url -> GNSSSeries? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(GNSSSeries.self, from: data)
            }
            .sorted { $0.station < $1.station }
        Self.cache.withLock { $0[eventId] = series }
        return series
    }

    private nonisolated static let cache = NSLockWrapped<[String: [GNSSSeries]]>([:])
}
