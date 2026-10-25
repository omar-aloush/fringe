import CryptoKit
import Foundation

/// Outcome of the in-app integrity check for one event's evidence record.
nonisolated enum AnchorState: Hashable, Sendable {
    /// No bundled `.ots` proof.
    case missing
    /// Proof present, waiting for inclusion in a Bitcoin block.
    case pending(calendarURI: String)
    /// Proof attested in a Bitcoin block (attested digest = block Merkle root).
    case confirmed(height: Int)
}

nonisolated struct EventIntegrity: Sendable {
    let eventId: String
    /// SHA-256 of the bundled record file, recomputed on-device.
    let digestHex: String
    /// SHA-256 recorded in the bundled build manifest, if present.
    let manifestHex: String?
    let anchor: AnchorState

    /// The record bytes are unchanged since they were hashed into the manifest.
    var digestMatch: Bool { manifestHex == digestHex }
    /// A matching digest is also attested in the bundled proof.
    var anchored: Bool {
        switch anchor {
        case .missing: return false
        case .pending: return digestMatch
        case .confirmed: return digestMatch
        }
    }

    var explorerURL: URL? {
        guard case let .confirmed(height) = anchor else { return nil }
        return URL(string: "https://mempool.space/block-height/\(height)")
    }
}

nonisolated struct EvidenceManifest: Codable, Sendable {
    struct Entry: Codable, Sendable {
        let eventId: String
        let file: String
        let sha256: String
    }

    let schema: String
    let algorithm: String
    let generatedAt: String
    let records: [Entry]

    nonisolated static func load() -> EvidenceManifest? {
        let url = Bundle.main.url(forResource: "evidence-manifest", withExtension: "json", subdirectory: "Evidence")
            ?? Bundle.main.url(forResource: "evidence-manifest", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(EvidenceManifest.self, from: data)
    }

    func entry(for eventId: String) -> Entry? {
        records.first { $0.eventId == eventId }
    }
}

/// Recomputes record digests on-device and reads the bundled OpenTimestamps
/// proofs. This establishes *record unchanged since anchoring* — it says
/// nothing about the scientific accuracy of the underlying measurements, and
/// the UI says so.
nonisolated enum EvidenceIntegrity {
    static func verify(eventId: String) -> EventIntegrity? {
        guard let data = EvidenceRecord.bundledData(eventId: eventId) else { return nil }
        let digest = Data(SHA256.hash(data: data))
        let digestHex = digest.map { String(format: "%02x", $0) }.joined()
        let manifestHex = EvidenceManifest.load()?.entry(for: eventId)?.sha256
        let anchor = anchorState(eventId: eventId, digest: digest)
        return EventIntegrity(
            eventId: eventId,
            digestHex: digestHex,
            manifestHex: manifestHex,
            anchor: anchor
        )
    }

    /// Parses the bundled proof for an event and checks it attests `digest`.
    static func anchorState(eventId: String, digest: [UInt8]) -> AnchorState {
        anchorState(eventId: eventId, digest: Data(digest))
    }

    static func anchorState(eventId: String, digest: Data) -> AnchorState {
        guard let url = Bundle.main.url(forResource: "evidence-\(eventId)", withExtension: "ots", subdirectory: "Evidence")
            ?? Bundle.main.url(forResource: "evidence-\(eventId)", withExtension: "ots"),
            let data = try? Data(contentsOf: url),
            let proof = try? OTSProof(data: data) else {
            return .missing
        }
        // The proof must encode the same digest we just recomputed.
        guard proof.digest == digest else { return .missing }

        if let btc = proof.bitcoin, let height = btc.height {
            return .confirmed(height: height)
        }
        return .pending(calendarURI: proof.pendingCalendar ?? "OpenTimestamps calendar")
    }
}
