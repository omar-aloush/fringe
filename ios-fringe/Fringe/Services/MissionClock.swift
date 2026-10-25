import Foundation

/// One modeled NISAR acquisition over a site.
nonisolated struct NisarPass: Identifiable, Hashable, Sendable {
    let date: Date
    let isAscending: Bool
    let durationSeconds: Double

    var id: String { "\(date.timeIntervalSince1970)|\(isAscending)" }
    var direction: String { isAscending ? "Ascending" : "Descending" }
}

/// Deterministic mission clock: models NISAR's baseline observation cadence per site.
///
/// NISAR flies a frozen 12-day repeat orbit (173 orbits per repeat, dawn–dusk
/// sun-synchronous). Each site receives one ascending and one descending
/// acquisition slot per cycle. Slots follow dawn/dusk local solar time and a
/// stable hash of the site id, so countdowns are reproducible across launches.
/// These are planning estimates, not live telemetry — always labeled as such in UI.
nonisolated enum MissionClock {
    static let repeatDays: Double = 12
    /// A site sits in the beam for tens of seconds per pass.
    static let acquisitionSeconds: Double = 28
    /// Fixed mission epoch — keeps every countdown reproducible.
    static let anchor: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 1
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 1_785_542_400)
    }()

    /// Next `count` modeled passes over the site, soonest first.
    static func passes(for event: DeformationEvent, after now: Date, count: Int = 3) -> [NisarPass] {
        Array(
            slots(for: event, after: now, isAscending: true, localHour: 6, count: 2)
                + slots(for: event, after: now, isAscending: false, localHour: 18, count: 2)
        )
        .sorted { $0.date < $1.date }
        .prefix(count)
        .map { $0 }
    }

    static func nextPass(for event: DeformationEvent, after now: Date) -> NisarPass? {
        passes(for: event, after: now, count: 1).first
    }

    /// Live countdown, e.g. "2d 14:22:08" or "04:12:56".
    static func countdown(from now: Date, to date: Date) -> String {
        let t = max(0, date.timeIntervalSince(now))
        let hms = String(
            format: "%02d:%02d:%02d",
            Int(t) % 86_400 / 3_600,
            Int(t) % 3_600 / 60,
            Int(t) % 60
        )
        let d = Int(t) / 86_400
        return d > 0 ? "\(d)d \(hms)" : hms
    }

    /// True while the site is inside the beam.
    static func isAcquiring(_ pass: NisarPass, at now: Date) -> Bool {
        now >= pass.date && now < pass.date.addingTimeInterval(pass.durationSeconds)
    }

    // MARK: - Slot math

    private static func slots(
        for event: DeformationEvent,
        after now: Date,
        isAscending: Bool,
        localHour: Double,
        count: Int
    ) -> [NisarPass] {
        let key = event.id + (isAscending ? "|asc" : "|dsc")
        let slot = Double(stableHash(key) % 12)
        // Dawn–dusk orbit: equator crossings hold ~6:00 / ~18:00 local solar time.
        var utcHour = (localHour - event.longitude / 15).truncatingRemainder(dividingBy: 24)
        if utcHour < 0 { utcHour += 24 }
        let jitterMinutes = Double(stableHash(key + "|min") % 44) - 22
        let cycleOffset = slot * 86_400 + utcHour * 3_600 + jitterMinutes * 60

        let elapsed = now.timeIntervalSince(anchor)
        let cycle = Int(max(0, elapsed / (repeatDays * 86_400)).rounded(.down))
        var result: [NisarPass] = []
        for k in cycle...(cycle + 2) where result.count < count {
            let date = anchor.addingTimeInterval(Double(k) * repeatDays * 86_400 + cycleOffset)
            if date >= now.addingTimeInterval(-acquisitionSeconds) {
                result.append(NisarPass(date: date, isAscending: isAscending, durationSeconds: acquisitionSeconds))
            }
        }
        return result
    }

    /// FNV-1a — stable across launches, unlike `hashValue`.
    private static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x1_0000_0001_b3
        }
        return Int(hash % 4_827_906_307)
    }
}
