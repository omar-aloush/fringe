import SwiftUI

/// Renders one interferogram off the main thread, keeping the previous frame visible while the next one renders.
struct FringeImageView: View {
    let request: FringeRequest
    var cached: Bool = true

    @State private var image: CGImage?

    var body: some View {
        let shown = (cached ? FringeRenderer.shared.cachedImage(for: request) : nil) ?? image
        ZStack {
            if let shown {
                Image(decorative: shown, scale: 1)
                    .resizable()
                    .interpolation(.medium)
            } else if request.style == .scene {
                Theme.surface
            } else {
                Color.clear
            }
        }
        .task(id: request) {
            if cached, let hit = FringeRenderer.shared.cachedImage(for: request) {
                image = hit
                return
            }
            if !cached {
                try? await Task.sleep(for: .milliseconds(10))
                if Task.isCancelled { return }
            }
            let req = request
            let useCache = cached
            let result = await Task.detached(priority: .userInitiated) { () -> RenderedImage? in
                FringeRenderer.shared.image(for: req, cached: useCache).map { RenderedImage(cgImage: $0) }
            }.value
            if Task.isCancelled { return }
            if let result { image = result.cgImage }
        }
    }
}

/// Pre-renders a sequence of frames across deformation scale 0…1 so scrubbing is a pure image swap.
struct FringeSequenceView: View {
    let key: String
    let scale: Double
    let makeRequest: @Sendable (Double) -> FringeRequest

    @State private var frames: [CGImage] = []
    @State private var loadedKey: String = ""

    private let frameCount = 48

    var body: some View {
        ZStack {
            if loadedKey == key, !frames.isEmpty {
                let index = min(frames.count - 1, max(0, Int((scale * Double(frames.count - 1)).rounded())))
                Image(decorative: frames[index], scale: 1)
                    .resizable()
                    .interpolation(.medium)
            } else {
                FringeImageView(request: makeRequest((scale * 4).rounded() / 4))
            }
        }
        .task(id: key) {
            let count = frameCount
            let builder = makeRequest
            let rendered = await Task.detached(priority: .userInitiated) { () -> [RenderedImage] in
                (0...count).compactMap { k in
                    let request = builder(Double(k) / Double(count))
                    return FringeRenderer.shared.image(for: request, cached: true).map { RenderedImage(cgImage: $0) }
                }
            }.value
            if Task.isCancelled { return }
            frames = rendered.map(\.cgImage)
            loadedKey = key
        }
    }
}

extension DeformationEvent {
    func sequenceKey(band: SARBand, style: FringeStyle, resolution: Int) -> String {
        "\(id)-\(band.rawValue)-\(style == .scene ? "s" : "o")-\(resolution)"
    }
}
