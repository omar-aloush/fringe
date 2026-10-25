import SwiftUI

enum LabMode: String, CaseIterable, Identifiable {
    case bowl, volcano, fault

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bowl: return "Aquifer subsidence"
        case .volcano: return "Volcano uplift"
        case .fault: return "Fault slip"
        }
    }

    var extentKm: Double {
        switch self {
        case .bowl: return 70
        case .volcano: return 36
        case .fault: return 100
        }
    }
}

/// State for the Interference Lab: one analytic source, a radar wavelength and a look direction.
@Observable
final class LabViewModel {
    var mode: LabMode = .bowl

    var depthKm: Double = 3.2
    var volumeKm3: Double = 0.02

    var slipM: Double = 1.5
    var faultDepthKm: Double = 12

    var bowlPeakM: Double = 0.30
    var bowlSigmaKm: Double = 16

    var wavelengthCm: Double = 23.8
    var isAscending: Bool = true
    var hasAtmosphere: Bool = true

    /// Name of the event loaded from "Open in Lab", if any.
    var loadedFrom: String?

    var geometry: LOSGeometry { isAscending ? .ascending : .descending }

    var model: DeformationModel {
        switch mode {
        case .volcano:
            return .mogi(depthKm: depthKm, volumeKm3: volumeKm3)
        case .fault:
            return .rupture(slipM: slipM, depthKm: faultDepthKm, strikeDeg: 35, lengthKm: 70)
        case .bowl:
            return .bowl(peakM: bowlPeakM, sigmaKm: bowlSigmaKm, aspect: 1.4, rotationDeg: 25)
        }
    }

    var stats: FringeStats {
        FringeRenderer.shared.stats(for: model, extentKm: mode.extentKm, geometry: geometry)
    }

    var fringes: Double { stats.fringes(wavelengthCm: wavelengthCm) }

    var request: FringeRequest {
        FringeRequest(
            model: model,
            scale: 1,
            extentKm: mode.extentKm,
            wavelengthCm: wavelengthCm,
            geometry: geometry,
            resolution: 220,
            style: .scene,
            atmosphereCm: hasAtmosphere ? 0.5 : 0,
            seed: 7
        )
    }

    /// Nearest real sensor for the current wavelength, if close.
    var nearestBand: SARBand? {
        SARBand.allCases.first { abs($0.wavelengthCm - wavelengthCm) < 0.6 }
    }

    var headline: String {
        switch mode {
        case .volcano:
            return "Mogi uplift · \(DeformationEvent.length(stats.peakVertical, signed: false)) peak"
        case .fault:
            return "Strike-slip · \(DeformationEvent.length(slipM, signed: false)) slip"
        case .bowl:
            return "Compaction · \(DeformationEvent.length(bowlPeakM, signed: false)) peak"
        }
    }

    func apply(_ event: DeformationEvent) {
        loadedFrom = event.name
        isAscending = event.geometry.isAscending
        wavelengthCm = SARBand.nisarL.wavelengthCm
        switch event.model {
        case let .mogi(depth, volume):
            mode = .volcano
            depthKm = min(max(depth, 0.5), 10)
            volumeKm3 = min(max(volume, 0.001), 0.1)
        case let .rupture(slip, depth, _, _):
            mode = .fault
            slipM = min(max(abs(slip), 0.05), 8)
            faultDepthKm = min(max(depth, 2), 25)
        case let .bowl(peak, sigma, _, _):
            mode = .bowl
            bowlPeakM = min(max(peak, 0.02), 1)
            bowlSigmaKm = min(max(sigma, 2), 25)
        case .flank:
            mode = .volcano
            depthKm = 3.2
            volumeKm3 = 0.02
        }
    }

    func reset() {
        loadedFrom = nil
        depthKm = 3.2
        volumeKm3 = 0.02
        slipM = 1.5
        faultDepthKm = 12
        bowlPeakM = 0.30
        bowlSigmaKm = 8
        wavelengthCm = 23.8
        isAscending = true
        hasAtmosphere = true
    }
}
