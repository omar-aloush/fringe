import SwiftUI

/// Evidence & Provenance panel: the structured record behind the visualization
/// — mission, dataset, per-item MEASURED/DERIVED/MODELED/LIVE labels,
/// limitations, sources, one-tap JSON export, and the integrity anchor.
struct EvidenceSheet: View {
    let event: DeformationEvent
    let onOpenIntegrity: () -> Void

    @State private var exportURL: URL?
    @State private var exportFailed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let record = EvidenceRecord.load(eventId: event.id) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        datasetReadout(record.dataset)
                        itemsCard(record)
                        limitationsCard(record)
                        sourcesCard(record)
                        exportCard(record)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            } else {
                Spacer()
                Text("No evidence record is bundled for this event yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.sage)
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.canvas)
        .background(SignalBackground().opacity(0.4).allowsHitTesting(false))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EVIDENCE & PROVENANCE").kicker(Theme.accent)
                Text("\(event.title) — \(event.episode)")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.sage)
                    .frame(width: 34, height: 34)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.stroke))
                    .contentShape(Circle())
            }
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Cards

    private func datasetReadout(_ dataset: EvidenceRecord.Dataset) -> some View {
        VStack(spacing: 0) {
            row("MISSION", dataset.mission)
            Divider().overlay(Theme.stroke)
            row("DATASET", dataset.datasetId)
            Divider().overlay(Theme.stroke)
            row("WINDOW", dataset.window)
            Divider().overlay(Theme.stroke)
            row("COVERAGE", dataset.coverage)
            Divider().overlay(Theme.stroke)
            row("GNSS", dataset.gnss)
            Divider().overlay(Theme.stroke)
            row("PROCESSING", dataset.processing)
        }
        .padding(.horizontal, 16)
        .fringeCard()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .kicker(Theme.sage)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private func itemsCard(_ record: EvidenceRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT YOU ARE LOOKING AT").kicker()
            ForEach(record.items, id: \.kind) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text(item.label)
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Self.tint(for: item.label))
                        .frame(width: 76, alignment: .leading)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Self.tint(for: item.label).opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Self.tint(for: item.label).opacity(0.4), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.kind)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.text)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.sage)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }

    private func limitationsCard(_ record: EvidenceRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "eye.slash")
                    .font(.caption.weight(.bold))
                Text("LIMITATIONS").kicker(Theme.amber)
            }
            ForEach(record.limitations, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Theme.amber.opacity(0.7)).frame(width: 5, height: 5).padding(.top, 5)
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(Theme.text.opacity(0.85))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }

    private func sourcesCard(_ record: EvidenceRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SOURCES").kicker()
            ForEach(record.sources, id: \.title) { source in
                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title)
                        .font(.subheadline)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(source.publisher) · \(source.year)")
                        .font(.caption)
                        .foregroundStyle(Theme.sage)
                    if let urlString = source.url, let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                Text("Open source")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }

    private func exportCard(_ record: EvidenceRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXPORT").kicker()
            if let exportURL {
                ShareLink(item: exportURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share evidence record (.json)")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(Theme.accent)
            } else {
                Button {
                    export(record)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: exportFailed ? "exclamationmark.triangle" : "square.and.arrow.up")
                        Text(exportFailed ? "Export unavailable" : "Prepare evidence record (.json)")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(exportFailed ? Theme.amber : Theme.accent)
            }

            Button {
                onOpenIntegrity()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Blockchain integrity anchor")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(PressableStyle())
            .foregroundStyle(Theme.lateral)

            Text("The record JSON is hashed (SHA-256) and time-stamped into the Bitcoin blockchain via OpenTimestamps. Verify before you trust.")
                .font(.caption2)
                .foregroundStyle(Theme.sage.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
        .task {
            if exportURL == nil && !exportFailed { export(record) }
        }
    }

    private func export(_ record: EvidenceRecord) {
        do {
            let data = try record.exportJSON()
            let dir = FileManager.default.temporaryDirectory
            let url = dir.appendingPathComponent("fringe-evidence-\(record.eventId).json")
            try data.write(to: url, options: .atomic)
            exportFailed = false
            exportURL = url
        } catch {
            exportFailed = true
        }
    }

    static func tint(for label: String) -> Color {
        switch label {
        case "MEASURED": return Theme.accent
        case "DERIVED": return Theme.lateral
        case "MODELED": return Theme.amber
        case "LIVE": return Theme.coral
        default: return Theme.sage
        }
    }
}
