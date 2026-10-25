import SwiftUI

/// In-app integrity view: recomputes the record digest, compares it with the
/// build manifest, reads the bundled OpenTimestamps proof, and links the
/// Bitcoin block explorer. States exactly what a matching proof proves —
/// record unchanged since anchoring — and what it does not.
struct IntegritySheet: View {
    let event: DeformationEvent
    @State private var integrity: EventIntegrity?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INTEGRITY ANCHOR").kicker(Theme.lateral)
                    Text(event.title)
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

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    climateBlockchainCard
                    if let integrity {
                        digestCard(integrity)
                        anchorCard(integrity)
                        honestyCard
                    } else {
                        Text("No evidence record is bundled for this event yet.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.sage)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.canvas)
        .background(SignalBackground().opacity(0.4).allowsHitTesting(false))
        .task { integrity = EvidenceIntegrity.verify(eventId: event.id) }
    }

    private var climateBlockchainCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("CLIMATE DATA IMMUTABILITY")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("Environmental baseline telemetry anchored to Bitcoin block headers to prevent tampering, retroactive revision, and greenwashing.")
                    .font(.caption)
                    .foregroundStyle(Theme.text.opacity(0.85))
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
    }

    private func digestCard(_ integrity: EventIntegrity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECORD DIGEST (SHA-256)").kicker()
            Text(integrity.digestHex)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.text)
                .lineLimit(4)
                .truncationMode(.middle)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surfaceRaised, in: .rect(cornerRadius: 10, style: .continuous))
            HStack(spacing: 6) {
                Image(systemName: integrity.digestMatch ? "checkmark.seal.fill" : "xmark.seal")
                Text(integrity.digestMatch ? "Matches the build manifest" : "Not in the bundled manifest")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(integrity.digestMatch ? Theme.accent : Theme.amber)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }

    @ViewBuilder
    private func anchorCard(_ integrity: EventIntegrity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OPENTIMESTAMPS ANCHOR").kicker()
            switch integrity.anchor {
            case .missing:
                Label("No bundled proof for this digest.", systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.amber)
            case .pending(let calendar):
                Label("PENDING — submitted to the OpenTimestamps calendar; Bitcoin confirmation can take up to ~48 hours.", systemImage: "hourglass")
                    .font(.subheadline)
                    .foregroundStyle(Theme.amber)
                    .fixedSize(horizontal: false, vertical: true)
                Text(calendar)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.sage)
            case .confirmed(let height):
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "link.badge.plus")
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CONFIRMED")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Theme.accent)
                            Text("Anchored in Bitcoin block \(height.formatted())")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.text)
                        }
                    }
                    Text("The attested digest is the Merkle root of this block.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.sage)
                    if let url = integrity.explorerURL {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari")
                                Text("Verify in block explorer")
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Theme.accent.opacity(0.14), in: .rect(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Formal cryptographic verification: run `ots verify` on the .ots proof from the repository — the in-app check covers digest match, proof structure, and the block reference.")
                        .font(.caption2)
                        .foregroundStyle(Theme.sage.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }

    private var honestyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT THIS PROVES — AND WHAT IT DOES NOT").kicker(Theme.amber)
            Text("A matching, anchored digest establishes that this exact evidence record has not changed since it was time-stamped into the Bitcoin blockchain.")
                .font(.subheadline)
                .foregroundStyle(Theme.text.opacity(0.9))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("It does not establish the scientific accuracy of the underlying measurements. Assess those through the cited sources in the Evidence panel.")
                .font(.subheadline)
                .foregroundStyle(Theme.sage)
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
