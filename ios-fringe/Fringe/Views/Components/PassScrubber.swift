import SwiftUI

/// Two-pass scrubber: pass 1 is the fixed reference, the playhead is the second acquisition.
struct PassScrubber: View {
    @Binding var progress: Double
    let event: DeformationEvent
    var onScrub: () -> Void = {}

    private let inset: CGFloat = 13

    var body: some View {
        let day = event.day(at: progress)
        let pass = day / 12 + 1
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Pass 1 · day 0")
                    .foregroundStyle(Theme.sage)
                Spacer()
                Text("Pass \(pass) · day \(day)")
                    .foregroundStyle(progress > 0.01 ? Theme.accent : Theme.sage)
                    .contentTransition(.numericText())
            }
            .font(.system(.footnote, design: .monospaced, weight: .medium))

            GeometryReader { geo in
                let width = geo.size.width - inset * 2
                let x = inset + width * CGFloat(progress)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 4)
                        .padding(.horizontal, inset)

                    Capsule()
                        .fill(LinearGradient(colors: [Theme.sage.opacity(0.4), Theme.accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, x - inset), height: 4)
                        .offset(x: inset)

                    ticks(width: width)

                    Circle()
                        .fill(Theme.surfaceRaised)
                        .overlay(Circle().stroke(Theme.sage.opacity(0.7), lineWidth: 2))
                        .frame(width: 22, height: 22)
                        .offset(x: inset - 11)

                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Theme.text.opacity(0.9), lineWidth: 2).padding(-4))
                        .shadow(color: Theme.accent.opacity(0.8), radius: 10)
                        .offset(x: x - 9)
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            onScrub()
                            let p = (value.location.x - inset) / max(width, 1)
                            progress = min(max(Double(p), 0), 1)
                        }
                )
            }
            .frame(height: 34)
        }
        .sensoryFeedback(.selection, trigger: hapticStep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pass pair scrubber")
        .accessibilityValue("Day \(day) of \(event.windowDays)")
        .accessibilityAdjustableAction { direction in
            onScrub()
            let step = 1 / Double(max(event.acquisitions, 1))
            switch direction {
            case .increment: progress = min(1, progress + step)
            case .decrement: progress = max(0, progress - step)
            @unknown default: break
            }
        }
    }

    private var hapticStep: Int {
        event.acquisitions <= 30 ? event.day(at: progress) : Int(progress * 20)
    }

    @ViewBuilder
    private func ticks(width: CGFloat) -> some View {
        let count = min(event.acquisitions, 30)
        if count > 1 {
            ForEach(1..<count, id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 1, height: i % 5 == 0 ? 12 : 7)
                    .offset(x: inset + width * CGFloat(i) / CGFloat(count), y: 12)
            }
        }
    }
}

/// Circular play/pause control paired with the scrubber.
struct PlayButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.text)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 62, height: 62)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .fringeGlass(Circle())
        .sensoryFeedback(.impact(weight: .light), trigger: isPlaying)
        .accessibilityLabel(isPlaying ? "Pause" : "Play the pass pair")
    }
}
