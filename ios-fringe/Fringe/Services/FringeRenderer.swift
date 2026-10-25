import SwiftUI
import CoreGraphics

nonisolated enum FringeStyle: Hashable {
    /// Transparent outside the deforming area; used on top of the map.
    case overlay
    /// Full-frame interferogram over synthetic dark SAR terrain.
    case scene
}

nonisolated struct FringeRequest: Hashable {
    var model: DeformationModel
    var scale: Double
    var extentKm: Double
    var wavelengthCm: Double
    var geometry: LOSGeometry = .ascending
    var resolution: Int
    var style: FringeStyle
    var atmosphereCm: Double = 0
    var seed: Int = 1
}

/// Thread-safe box for passing rendered images across concurrency domains.
nonisolated struct RenderedImage: @unchecked Sendable {
    let cgImage: CGImage
}

/// Synthesizes wrapped interferograms from analytic deformation models.
/// Phase = LOS displacement ÷ (λ/2), wrapped into one color cycle per fringe.
nonisolated final class FringeRenderer: @unchecked Sendable {
    static let shared = FringeRenderer()

    private struct StatsKey: Hashable {
        let model: DeformationModel
        let extentKm: Double
        let geometry: LOSGeometry
    }

    private struct NoiseKey: Hashable {
        let resolution: Int
        let seed: Int
    }

    private struct NoiseField {
        let aps: [Float]
        let grain: [Float]
        let terrain: [Float]
    }

    private let lut: [SIMD3<Float>]
    private var imageCache: [FringeRequest: CGImage] = [:]
    private var statsCache: [StatsKey: FringeStats] = [:]
    private var noiseCache: [NoiseKey: NoiseField] = [:]
    private let lock = NSLock()
    private var speckleImage: CGImage?

    private init() {
        lut = Self.makeLUT()
    }

    // MARK: - Stats

    /// Stats at scale 1. Displacement is linear in scale, so callers use `scaled(by:)`.
    func stats(for model: DeformationModel, extentKm: Double, geometry: LOSGeometry) -> FringeStats {
        let key = StatsKey(model: model, extentKm: extentKm, geometry: geometry)
        lock.lock()
        let hit = statsCache[key]
        lock.unlock()
        if let hit { return hit }

        let field = model.field()
        let s = geometry.vector
        let n = 73
        var minL = Double.greatestFiniteMagnitude
        var maxL = -Double.greatestFiniteMagnitude
        var peakV = 0.0
        var peakH = 0.0
        for j in 0..<n {
            let y = (0.5 - Double(j) / Double(n - 1)) * extentKm
            for i in 0..<n {
                let x = (Double(i) / Double(n - 1) - 0.5) * extentKm
                let u = field(x, y)
                let los = u.x * s.x + u.y * s.y + u.z * s.z
                minL = min(minL, los)
                maxL = max(maxL, los)
                if abs(u.z) > abs(peakV) { peakV = u.z }
                peakH = max(peakH, (u.x * u.x + u.y * u.y).squareRoot())
            }
        }
        let result = FringeStats(minLOS: minL, maxLOS: maxL, peakVertical: peakV, peakHorizontal: peakH)
        lock.lock()
        if statsCache.count > 300 { statsCache.removeAll() }
        statsCache[key] = result
        lock.unlock()
        return result
    }

    // MARK: - Images

    /// Returns an already-rendered image without doing any work.
    func cachedImage(for request: FringeRequest) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        return imageCache[request]
    }

    func image(for request: FringeRequest, cached: Bool) -> CGImage? {
        if cached, let hit = cachedImage(for: request) { return hit }
        guard let image = render(request) else { return nil }
        if cached {
            lock.lock()
            if imageCache.count > 300 { imageCache.removeAll() }
            imageCache[request] = image
            lock.unlock()
        }
        return image
    }

    /// Tileable radar-speckle texture for screen backgrounds.
    func speckle() -> CGImage? {
        lock.lock()
        let existing = speckleImage
        lock.unlock()
        if let existing { return existing }
        let res = 192
        var pixels = [UInt8](repeating: 0, count: res * res * 4)
        for j in 0..<res {
            for i in 0..<res {
                let h = Self.hash(Int32(i), Int32(j), 977)
                let v = UInt8(pow(h, 3) * 255)
                let p = (j * res + i) * 4
                pixels[p] = v
                pixels[p + 1] = v
                pixels[p + 2] = v
                pixels[p + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                width: res, height: res, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: res * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { return nil }
        lock.lock()
        speckleImage = image
        lock.unlock()
        return image
    }

    private func render(_ request: FringeRequest) -> CGImage? {
        let res = max(request.resolution, 8)
        let field = request.model.field()
        let s = request.geometry.vector
        let halfLambda = max(request.wavelengthCm, 0.5) / 200
        let noise = noiseField(resolution: res, seed: request.seed)
        let lut = self.lut
        let ext = request.extentKm
        let scale = request.scale
        let atmosphere = request.atmosphereCm / 100
        let denom = Double(res - 1)
        let isOverlay = request.style == .overlay

        var pixels = [UInt8](repeating: 0, count: res * res * 4)

        func byte(_ v: Float) -> UInt8 {
            UInt8(max(0, min(255, v * 255)))
        }

        pixels.withUnsafeMutableBufferPointer { buf in
            for j in 0..<res {
                let fy = Double(j) / denom
                let y = (0.5 - fy) * ext
                let ny = (fy - 0.5) * 2
                for i in 0..<res {
                    let fx = Double(i) / denom
                    let x = (fx - 0.5) * ext
                    let nx = (fx - 0.5) * 2
                    let idx = j * res + i

                    let u = field(x, y) * scale
                    let losModel = u.x * s.x + u.y * s.y + u.z * s.z
                    let los = losModel + Double(noise.aps[idx]) * atmosphere
                    let cycles = los / halfLambda
                    let frac = cycles - cycles.rounded(.down)
                    let color = lut[min(255, max(0, Int(frac * 256)))]
                    let grain = noise.grain[idx]
                    let rn = (nx * nx + ny * ny).squareRoot()
                    let strength = Self.smoothstep(0.03, 0.28, abs(losModel) / halfLambda)

                    let p = idx * 4
                    if isOverlay {
                        let edge = 1 - Self.smoothstep(0.6, 0.98, rn)
                        let a = Float(strength * edge) * 0.94
                        let c = color * grain
                        buf[p] = byte(c.x * a)
                        buf[p + 1] = byte(c.y * a)
                        buf[p + 2] = byte(c.z * a)
                        buf[p + 3] = byte(a)
                    } else {
                        let t = noise.terrain[idx] * grain
                        let base = SIMD3<Float>(t * 0.86, t * 0.95, t)
                        let edge = 1 - Self.smoothstep(0.78, 1.25, rn) * 0.75
                        let mixA = Float((0.1 + 0.82 * strength) * edge)
                        let c = base * (1 - mixA) + color * grain * mixA
                        buf[p] = byte(c.x)
                        buf[p + 1] = byte(c.y)
                        buf[p + 2] = byte(c.z)
                        buf[p + 3] = 255
                    }
                }
            }
        }

        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: res,
            height: res,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: res * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - Noise

    private func noiseField(resolution res: Int, seed: Int) -> NoiseField {
        let key = NoiseKey(resolution: res, seed: seed)
        lock.lock()
        let hit = noiseCache[key]
        lock.unlock()
        if let hit { return hit }

        let count = res * res
        var aps = [Float](repeating: 0, count: count)
        var grain = [Float](repeating: 1, count: count)
        var terrain = [Float](repeating: 0, count: count)
        let sd = Int32(truncatingIfNeeded: seed)
        let fr = Float(res)

        for j in 0..<res {
            for i in 0..<res {
                let u = Float(i) / fr
                let v = Float(j) / fr
                let idx = j * res + i
                aps[idx] = Self.fbm(u * 2.5, v * 2.5, sd, octaves: 3) * 2 - 1
                grain[idx] = 0.72 + 0.45 * Self.hash(Int32(i), Int32(j), sd &+ 101)
                let base = Self.fbm(u * 4 + 11, v * 4 + 7, sd &+ 7, octaves: 4)
                let ridgeRaw = Self.fbm(u * 8, v * 8, sd &+ 13, octaves: 3)
                let ridge = 1 - abs(ridgeRaw * 2 - 1)
                terrain[idx] = 0.03 + 0.2 * pow(base, 1.4) + 0.09 * ridge * ridge
            }
        }
        let field = NoiseField(aps: aps, grain: grain, terrain: terrain)
        lock.lock()
        if noiseCache.count > 40 { noiseCache.removeAll() }
        noiseCache[key] = field
        lock.unlock()
        return field
    }

    private static func hash(_ x: Int32, _ y: Int32, _ s: Int32) -> Float {
        var h = UInt32(bitPattern: x &* 374_761_393 &+ y &* 668_265_263 &+ s &* 1_442_695_041)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Float(h & 0xFFFFFF) / Float(0xFFFFFF)
    }

    private static func valueNoise(_ x: Float, _ y: Float, _ s: Int32) -> Float {
        let x0 = x.rounded(.down)
        let y0 = y.rounded(.down)
        let ix = Int32(x0)
        let iy = Int32(y0)
        let fx = x - x0
        let fy = y - y0
        let sx = fx * fx * (3 - 2 * fx)
        let sy = fy * fy * (3 - 2 * fy)
        let a = hash(ix, iy, s)
        let b = hash(ix &+ 1, iy, s)
        let c = hash(ix, iy &+ 1, s)
        let d = hash(ix &+ 1, iy &+ 1, s)
        let top = a + (b - a) * sx
        let bottom = c + (d - c) * sx
        return top + (bottom - top) * sy
    }

    private static func fbm(_ x: Float, _ y: Float, _ s: Int32, octaves: Int) -> Float {
        var sum: Float = 0
        var amp: Float = 0.5
        var freq: Float = 1
        var norm: Float = 0
        for o in 0..<octaves {
            sum += amp * valueNoise(x * freq, y * freq, s &+ Int32(o) &* 31)
            norm += amp
            amp *= 0.5
            freq *= 2
        }
        return sum / norm
    }

    private static func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
        let t = min(max((x - e0) / (e1 - e0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private static func makeLUT() -> [SIMD3<Float>] {
        let stops = Theme.fringeStops + [Theme.fringeStops[0]]
        let rgb: [SIMD3<Float>] = stops.map { hex in
            SIMD3<Float>(
                Float((hex >> 16) & 0xFF) / 255,
                Float((hex >> 8) & 0xFF) / 255,
                Float(hex & 0xFF) / 255
            )
        }
        let segments = rgb.count - 1
        var out: [SIMD3<Float>] = []
        out.reserveCapacity(256)
        for i in 0..<256 {
            let t = Float(i) / 256 * Float(segments)
            let k = min(Int(t), segments - 1)
            let f = t - Float(k)
            out.append(rgb[k] + (rgb[k + 1] - rgb[k]) * f)
        }
        return out
    }
}
