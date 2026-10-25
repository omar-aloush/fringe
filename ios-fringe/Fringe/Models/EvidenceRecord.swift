import Foundation

/// The structured evidence & provenance record for one event, bundled as JSON
/// (`evidence-<eventId>.json`) and hashed into the OpenTimestamps manifest.
///
/// The record is the app's single source of truth for what is measured, what is
/// modeled, where every number comes from, and what the evidence cannot tell
/// us. The grounded Q&A feature may only use this record as context.
nonisolated struct EvidenceRecord: Codable, Hashable, Identifiable, Sendable {
    struct Dossier: Codable, Hashable, Sendable {
        struct Section: Codable, Hashable, Sendable {
            let icon: String
            let title: String
            let body: String
        }

        let headline: String
        let sections: [Section]
    }

    /// Pre-generated climate interpretation, written from the cited sources at
    /// build time so it is always available offline. The three keys match the
    /// Explain This audience levels.
    struct Interpretation: Codable, Hashable, Sendable {
        let publicText: String
        let studentText: String
        let scientistText: String

        enum CodingKeys: String, CodingKey {
            case publicText = "public"
            case studentText = "student"
            case scientistText = "scientist"
        }

        func text(for level: AudienceLevel) -> String {
            switch level {
            case .everyone: return publicText
            case .student: return studentText
            case .scientist: return scientistText
            }
        }
    }

    struct Item: Codable, Hashable, Sendable {
        /// One of MEASURED / DERIVED / MODELED / LIVE.
        let label: String
        let kind: String
        let detail: String
    }

    struct Source: Codable, Hashable, Sendable {
        let title: String
        let publisher: String
        let year: String
        let url: String?
    }

    struct Dataset: Codable, Hashable, Sendable {
        let mission: String
        let datasetId: String
        let window: String
        let coverage: String
        let gnss: String
        let processing: String
    }

    let schema: String
    let eventId: String
    let eventName: String
    let region: String
    let episode: String
    /// "substantive" | "condensed" | "none-claimed"
    let climateLink: String
    let climateNote: String?
    let dossier: Dossier?
    let interpretation: Interpretation?
    let dataset: Dataset
    let items: [Item]
    let limitations: [String]
    let sources: [Source]
    let generatedAt: String

    var id: String { eventId }

    var labelColor: String { climateLink }

    /// The full record as exportable JSON (pretty-printed for human readers).
    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    // MARK: - Bundled records

    /// Loads the bundled record for an event. Cached — detail re-renders per frame.
    nonisolated static func load(eventId: String) -> EvidenceRecord? {
        if let cached = Self.cache.withLock({ $0[eventId] }) { return cached }
        let url = Bundle.main.url(forResource: "evidence-\(eventId)", withExtension: "json", subdirectory: "Evidence")
            ?? Bundle.main.url(forResource: "evidence-\(eventId)", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url),
              let record = try? JSONDecoder().decode(EvidenceRecord.self, from: data) else {
            return nil
        }
        Self.cache.withLock { $0[eventId] = record }
        return record
    }

    /// Raw bytes of the bundled record file, exactly as hashed into the manifest.
    nonisolated static func bundledData(eventId: String) -> Data? {
        let url = Bundle.main.url(forResource: "evidence-\(eventId)", withExtension: "json", subdirectory: "Evidence")
            ?? Bundle.main.url(forResource: "evidence-\(eventId)", withExtension: "json")
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }

    nonisolated static func loadAll(eventIds: [String]) -> [EvidenceRecord] {
        eventIds.compactMap { load(eventId: $0) }
    }

    private nonisolated static let cache = NSLockWrapped<[String: EvidenceRecord]>([:])
}
