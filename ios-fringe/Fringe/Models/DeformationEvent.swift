import SwiftUI
import MapKit

nonisolated enum EventKind: String, Hashable {
    case uplift, subsidence, faultSlip, flank

    var label: String {
        switch self {
        case .uplift: return "Uplift"
        case .subsidence: return "Subsidence"
        case .faultSlip: return "Fault slip"
        case .flank: return "Flank slide"
        }
    }

    var motionWord: String {
        switch self {
        case .uplift: return "uplift"
        case .subsidence: return "sinking"
        case .faultSlip: return "offset"
        case .flank: return "seaward"
        }
    }

    var color: Color {
        switch self {
        case .uplift: return Theme.amber
        case .subsidence: return Theme.coral
        case .faultSlip, .flank: return Theme.lateral
        }
    }

    var symbol: String {
        switch self {
        case .uplift: return "arrow.up.circle"
        case .subsidence: return "arrow.down.circle"
        case .faultSlip: return "arrow.left.arrow.right.circle"
        case .flank: return "arrow.down.right.circle"
        }
    }

    var category: EventCategory {
        switch self {
        case .uplift, .flank: return .volcanoes
        case .subsidence: return .cities
        case .faultSlip: return .faults
        }
    }
}

nonisolated enum EventCategory: String, CaseIterable, Identifiable {
    case all, climate, cities, volcanoes, faults

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .climate: return "Climate cases"
        case .cities: return "Sinking ground"
        case .volcanoes: return "Volcanoes"
        case .faults: return "Faults"
        }
    }
}

nonisolated enum RateUnit: Hashable {
    case day, month, year, coseismic
}

/// A published, citable measurement.
nonisolated struct PublishedFact: Hashable, Identifiable {
    let value: String
    let label: String
    let source: String

    var id: String { label }
}

/// A real deformation site with its published record and the analytic model used to render it.
nonisolated struct DeformationEvent: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let episode: String
    let kind: EventKind
    let latitude: Double
    let longitude: Double
    let model: DeformationModel
    let extentKm: Double
    let geometry: LOSGeometry
    /// Span of the pass pair in days. Always a multiple of NISAR's 12-day repeat.
    let windowDays: Int
    let rateUnit: RateUnit
    /// For earthquakes: day within the window when the rupture happens.
    let coseismicDay: Int?
    let headline: String
    let story: String
    let facts: [PublishedFact]
    let seed: Int

    static func == (lhs: DeformationEvent, rhs: DeformationEvent) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var title: String { "\(name), \(region)" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Camera region that frames the interferogram in the upper part of the map, above the floating panel.
    func mapRegion(padding: Double = 2.1) -> MKCoordinateRegion {
        let meters = extentKm * padding * 1000
        let shifted = CLLocationCoordinate2D(latitude: latitude - extentKm * 0.32 / 110.574, longitude: longitude)
        return MKCoordinateRegion(center: shifted, latitudinalMeters: meters, longitudinalMeters: meters)
    }

    // MARK: - Time

    var acquisitions: Int { windowDays / 12 }

    /// Day of the nearest 12-day acquisition for a scrubber position.
    func day(at progress: Double) -> Int {
        Int((min(max(progress, 0), 1) * Double(acquisitions)).rounded()) * 12
    }

    /// Fraction of the full deformation reached at a scrubber position.
    func scale(at progress: Double) -> Double {
        let p = min(max(progress, 0), 1)
        guard let day = coseismicDay else { return p }
        let f = Double(day) / Double(windowDays)
        let t = min(max((p - (f - 0.025)) / 0.05, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Acquisition days shown on the detail timeline.
    var timelineDays: [Int] {
        if acquisitions <= 4 {
            return (0...acquisitions).map { $0 * 12 }
        }
        return (0...4).map { i in
            Int((Double(acquisitions) * Double(i) / 4).rounded()) * 12
        }
    }

    var windowText: String {
        if windowDays >= 720 { return "\(Fmt.n(Double(windowDays) / 365.25, 1)) yr" }
        if windowDays >= 90 { return "\(Int((Double(windowDays) / 30.44).rounded())) mo" }
        return "\(windowDays) days"
    }

    // MARK: - Measurements

    func stats(scale: Double) -> FringeStats {
        FringeRenderer.shared.stats(for: model, extentKm: extentKm, geometry: geometry).scaled(by: scale)
    }

    /// Headline motion in meters (signed for vertical kinds).
    func motion(_ stats: FringeStats) -> Double {
        switch kind {
        case .uplift, .subsidence: return stats.peakVertical
        case .faultSlip: return stats.peakHorizontal * 2
        case .flank: return stats.peakHorizontal
        }
    }

    func motionText(scale: Double) -> String {
        let m = motion(stats(scale: scale))
        switch kind {
        case .uplift, .subsidence:
            return Self.length(m, signed: true)
        case .faultSlip, .flank:
            return Self.length(m, signed: false)
        }
    }

    var rateText: String {
        let full = abs(motion(stats(scale: 1))) * 100
        let days = Double(windowDays)
        switch rateUnit {
        case .day: return "\(Fmt.n(full / days, 2)) cm/day"
        case .month: return "\(Fmt.n(full / days * 30.44, 1)) cm/mo"
        case .year: return "\(Fmt.n(full / days * 365.25, 1)) cm/yr"
        case .coseismic: return "Coseismic"
        }
    }

    static func length(_ meters: Double, signed: Bool) -> String {
        let value = signed ? meters : abs(meters)
        let sign = signed && value > 0.0005 ? "+" : ""
        if abs(value) >= 1 {
            return sign + Fmt.n(value, 2) + " m"
        }
        return sign + Fmt.n(value * 100, 1) + " cm"
    }

    // MARK: - Rendering

    func sceneRequest(band: SARBand, scale: Double, resolution: Int) -> FringeRequest {
        FringeRequest(
            model: model,
            scale: scale,
            extentKm: extentKm,
            wavelengthCm: band.wavelengthCm,
            geometry: geometry,
            resolution: resolution,
            style: .scene,
            atmosphereCm: 0.6,
            seed: seed
        )
    }

    func overlayRequest(band: SARBand, scale: Double, resolution: Int) -> FringeRequest {
        FringeRequest(
            model: model,
            scale: scale,
            extentKm: extentKm,
            wavelengthCm: band.wavelengthCm,
            geometry: geometry,
            resolution: resolution,
            style: .overlay,
            atmosphereCm: 0.6,
            seed: seed
        )
    }

    func shareText(band: SARBand) -> String {
        let n = stats(scale: 1).fringes(wavelengthCm: band.wavelengthCm)
        return "\(title) — \(episode). \(motionText(scale: 1)) \(kind.motionWord) over \(windowText) (\(rateText)), \(Fmt.n(n, 1)) fringes in \(band.label). Seen with Fringe, a NISAR radar explorer."
    }
}
