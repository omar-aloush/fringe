import Foundation

/// Ground displacement in meters: (east, north, up).
typealias Displacement = SIMD3<Double>

/// Analytic elastic-half-space deformation sources used to synthesize interferograms.
nonisolated enum DeformationModel: Hashable {
    /// Mogi (1958) point pressure source with Poisson ratio 0.25. Positive volume inflates.
    case mogi(depthKm: Double, volumeKm3: Double)
    /// Vertical strike-slip fault slipping uniformly from the surface to `depthKm`
    /// (2-D screw dislocation, tapered along strike).
    case rupture(slipM: Double, depthKm: Double, strikeDeg: Double, lengthKm: Double)
    /// Aquifer-compaction bowl with an elliptical Gaussian footprint. `rotationDeg` is measured from east.
    case bowl(peakM: Double, sigmaKm: Double, aspect: Double, rotationDeg: Double)
    /// Gravitational flank slide: horizontal motion toward `azimuthDeg` plus proportional vertical motion.
    case flank(peakM: Double, sigmaKm: Double, azimuthDeg: Double, verticalRatio: Double)

    /// Returns a displacement function of map position in km (x east, y north).
    func field() -> (Double, Double) -> Displacement {
        switch self {
        case let .mogi(depthKm, volumeKm3):
            let d = max(depthKm, 0.05) * 1000
            // (1 − ν)·ΔV / π with ν = 0.25  →  3ΔV / 4π
            let c = 3 * volumeKm3 * 1e9 / (4 * Double.pi)
            return { x, y in
                let xm = x * 1000
                let ym = y * 1000
                let r3 = pow(xm * xm + ym * ym + d * d, 1.5)
                let k = c / r3
                return Displacement(k * xm, k * ym, k * d)
            }
        case let .rupture(slipM, depthKm, strikeDeg, lengthKm):
            let phi = strikeDeg * .pi / 180
            let ae = sin(phi), an = cos(phi)
            let pe = cos(phi), pn = -sin(phi)
            let depth = max(depthKm, 0.05)
            let half = lengthKm / 2
            let taperWidth = max(lengthKm * 0.12, depth)
            return { x, y in
                let along = x * ae + y * an
                let perp = x * pe + y * pn
                let taper = 0.5 * (1 - tanh((abs(along) - half) / taperWidth))
                // u(x) = (s/π)·atan(D/x): a step of s across the fault decaying with distance.
                let u = slipM / .pi * atan(depth / perp) * taper
                return Displacement(u * ae, u * an, 0)
            }
        case let .bowl(peakM, sigmaKm, aspect, rotationDeg):
            let th = rotationDeg * .pi / 180
            let ct = cos(th), st = sin(th)
            let s2 = 2 * sigmaKm * sigmaKm
            let asp = max(aspect, 0.1)
            return { x, y in
                let xr = x * ct + y * st
                let yr = -x * st + y * ct
                let q = (xr * xr) / (asp * asp) + yr * yr
                return Displacement(0, 0, -peakM * exp(-q / s2))
            }
        case let .flank(peakM, sigmaKm, azimuthDeg, verticalRatio):
            let az = azimuthDeg * .pi / 180
            let de = sin(az), dn = cos(az)
            let s2 = 2 * sigmaKm * sigmaKm
            return { x, y in
                let g = peakM * exp(-(x * x + y * y) / s2)
                return Displacement(g * de, g * dn, verticalRatio * g)
            }
        }
    }

    var summary: String {
        switch self {
        case let .mogi(d, v):
            return "Mogi point source · \(Fmt.n(d, 1)) km deep · ΔV \(Fmt.n(v * 1000, 1)) M m³"
        case let .rupture(s, d, _, l):
            return "Strike-slip dislocation · \(Fmt.n(s, 2)) m slip · 0–\(Fmt.n(d, 0)) km · \(Fmt.n(l, 0)) km long"
        case let .bowl(p, sigma, _, _):
            return "Compaction bowl · \(Fmt.n(p * 100, 0)) cm peak · σ \(Fmt.n(sigma, 0)) km"
        case let .flank(p, sigma, az, _):
            return "Flank slide · \(Fmt.n(p * 100, 0)) cm toward \(Fmt.n(az, 0))° · σ \(Fmt.n(sigma, 0)) km"
        }
    }
}

/// Radar viewing geometry. NISAR is left-looking; incidence spans ~33–47° across the swath.
nonisolated struct LOSGeometry: Hashable {
    var incidenceDeg: Double
    /// Horizontal direction from the ground toward the satellite, degrees clockwise from north.
    var groundToSatelliteAzimuthDeg: Double
    var isAscending: Bool

    /// Ascending pass heading ≈ 348°, looking left (west): satellite lies to the east-northeast.
    static let ascending = LOSGeometry(incidenceDeg: 37, groundToSatelliteAzimuthDeg: 78, isAscending: true)
    /// Descending pass heading ≈ 192°, looking left (east): satellite lies to the west-northwest.
    static let descending = LOSGeometry(incidenceDeg: 37, groundToSatelliteAzimuthDeg: 282, isAscending: false)

    /// Unit vector from ground to satellite (east, north, up).
    var vector: Displacement {
        let th = incidenceDeg * .pi / 180
        let az = groundToSatelliteAzimuthDeg * .pi / 180
        return Displacement(sin(th) * sin(az), sin(th) * cos(az), cos(th))
    }

    var label: String {
        "\(isAscending ? "Ascending" : "Descending") · \(Fmt.n(incidenceDeg, 0))°"
    }
}

/// Radar bands relevant to interferometry.
nonisolated enum SARBand: String, CaseIterable, Identifiable, Hashable {
    case nisarL, nisarS, sentinelC

    var id: String { rawValue }

    var wavelengthCm: Double {
        switch self {
        case .nisarL: return 23.8
        case .nisarS: return 9.4
        case .sentinelC: return 5.55
        }
    }

    /// Line-of-sight motion represented by one full color cycle (λ/2, two-way path).
    var fringeCm: Double { wavelengthCm / 2 }

    var letter: String {
        switch self {
        case .nisarL: return "L"
        case .nisarS: return "S"
        case .sentinelC: return "C"
        }
    }

    var label: String {
        switch self {
        case .nisarL: return "NISAR L-band"
        case .nisarS: return "NISAR S-band"
        case .sentinelC: return "Sentinel-1 C-band"
        }
    }
}

/// Summary statistics of a displacement field as seen by the radar.
nonisolated struct FringeStats: Hashable {
    var minLOS: Double
    var maxLOS: Double
    var peakVertical: Double
    var peakHorizontal: Double

    static let zero = FringeStats(minLOS: 0, maxLOS: 0, peakVertical: 0, peakHorizontal: 0)

    var losRange: Double { maxLOS - minLOS }
    var peakLOS: Double { abs(maxLOS) >= abs(minLOS) ? maxLOS : minLOS }

    /// Number of color cycles across the scene: N = ΔLOS ÷ (λ/2).
    func fringes(wavelengthCm: Double) -> Double {
        losRange / (wavelengthCm / 200)
    }

    func scaled(by s: Double) -> FringeStats {
        FringeStats(
            minLOS: minLOS * s,
            maxLOS: maxLOS * s,
            peakVertical: peakVertical * s,
            peakHorizontal: peakHorizontal * s
        )
    }
}
