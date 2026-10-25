import SwiftUI

/// Glass chips overlaid on the interferogram hero, styled after ExplainChip.
private struct ChipBase: View {
    let systemImage: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .fringeGlass(Capsule())
    }
}

/// Opens the Evidence & Provenance panel for the current event.
struct EvidenceChip: View {
    let action: () -> Void

    var body: some View {
        ChipBase(systemImage: "checkmark.seal", title: "Evidence", tint: Theme.accent, action: action)
            .accessibilityLabel("Open evidence and provenance")
    }
}

/// Opens grounded "Ask this event" Q&A.
struct AskChip: View {
    let action: () -> Void

    var body: some View {
        ChipBase(systemImage: "bubble.left.and.text.bubble.right", title: "Ask", tint: Theme.lateral, action: action)
            .accessibilityLabel("Ask a question about this event")
    }
}
