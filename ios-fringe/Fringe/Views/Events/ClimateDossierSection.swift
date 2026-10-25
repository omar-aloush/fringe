import SwiftUI

/// The climate dossier card: six honest sections per eligible event, plus the
/// pre-generated three-level interpretation. For tectonic/volcanic events this
/// renders the "climate connection: none claimed" honesty note instead.
struct ClimateDossierSection: View {
    let record: EvidenceRecord?
    @State private var level: AudienceLevel = .everyone

    var body: some View {
        if let record {
            content(for: record)
        }
    }

    @ViewBuilder
    private func content(for record: EvidenceRecord) -> some View {
        if let note = record.climateNote, record.dossier == nil {
            noteCard(note)
        } else if let dossier = record.dossier {
            dossierCard(dossier, record: record)
        }
    }

    // MARK: - Full dossier

    private func dossierCard(_ dossier: EvidenceRecord.Dossier, record: EvidenceRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CLIMATE DOSSIER").kicker(Theme.accent)
                Spacer()
                Text(record.climateLink.uppercased())
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Theme.sage)
            }

            Text(dossier.headline)
                .font(.headline)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(dossier.sections, id: \.title) { section in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: section.icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30, height: 30)
                        .background(Theme.accent.opacity(0.1), in: Circle())
                        .overlay(Circle().stroke(Theme.accent.opacity(0.25)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.text)
                        Text(section.body)
                            .font(.subheadline)
                            .foregroundStyle(Theme.text.opacity(0.85))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }

            if let interpretation = record.interpretation {
                Divider().overlay(Theme.stroke)
                Text("PRE-GENERATED INTERPRETATION").kicker()
                AudienceLevels(levels: AudienceLevel.allCases, selection: $level)
                Text(interpretation.text(for: level))
                    .font(.subheadline)
                    .foregroundStyle(Theme.text.opacity(0.9))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(level)
                    .transition(.opacity)
                    .animation(.snappy(duration: 0.2), value: level)
                Text("Written from the cited sources when this record was prepared — no network needed.")
                    .font(.caption2)
                    .foregroundStyle(Theme.sage.opacity(0.85))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }

    // MARK: - Honesty note (geology-only events)

    private func noteCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption.weight(.bold))
                Text("CLIMATE CONNECTION: NONE CLAIMED").kicker(Theme.amber)
            }
            Text(note)
                .font(.subheadline)
                .foregroundStyle(Theme.text.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.amber.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Compact three-way level switch, styled like the Explain audience picker.
struct AudienceLevels: View {
    let levels: [AudienceLevel]
    @Binding var selection: AudienceLevel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(levels) { level in
                let isSelected = level == selection
                Button {
                    selection = level
                } label: {
                    Text(level.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.text : Theme.sage)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Theme.accent.opacity(0.16))
                                    .overlay(Capsule().stroke(Theme.accent.opacity(0.45), lineWidth: 1))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke))
        .sensoryFeedback(.selection, trigger: selection)
    }
}
