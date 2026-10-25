//
//  FringeTests.swift
//  FringeTests
//
//  Unit tests for the climate-evidence layer: evidence records, dossiers,
//  SHA-256 digests, OpenTimestamps proof parsing, and GNSS bundles.
//

import CryptoKit
import Foundation
import Testing
@testable import Fringe

@MainActor
struct FringeTests {

    // MARK: - Physics & formatting math

    @Test func oneFringeIsHalfWavelength() {
        for band in SARBand.allCases {
            #expect(abs(band.fringeCm - band.wavelengthCm / 2) < 0.0001)
        }
    }

    @Test func lengthFormatting() {
        #expect(DeformationEvent.length(0.019, signed: true) == "+1.9 cm")
        #expect(DeformationEvent.length(-0.019, signed: true) == "−1.9 cm")
        #expect(DeformationEvent.length(0.30, signed: false) == "30.0 cm")
        #expect(DeformationEvent.length(1.0, signed: false) == "1.00 m")
    }

    @Test func norfolkWindowMath() {
        let e = EventCatalog.event(id: "norfolk")
        #expect(e.windowDays == 1584)               // 132 × 12-day repeat
        #expect(e.windowDays % 12 == 0)
        #expect(e.windowText == "4.3 yr")
        #expect(e.rateUnit == .year)
        // Chosen parameters encode the published rate: 1.9 cm over 1,584 days ≈ 4.4 mm/yr.
        guard case let .bowl(peakM, _, _, _) = e.model else {
            Issue.record("norfolk model is not a bowl")
            return
        }
        let mmPerYear = peakM * 1000 / Double(e.windowDays) * 365.25
        #expect(abs(mmPerYear - 4.4) < 0.3)
    }

    // MARK: - Evidence records (all events)

    @Test func everyEventHasAnEvidenceRecord() throws {
        for event in EventCatalog.all {
            let record = try #require(EvidenceRecord.load(eventId: event.id))
            #expect(record.schema == "fringe.evidence/1")
            #expect(record.eventId == event.id)
            #expect(!record.items.isEmpty)
            #expect(!record.sources.isEmpty)
            #expect(!record.limitations.isEmpty)
            #expect(["substantive", "condensed", "none-claimed"].contains(record.climateLink))
            // Every modeled scene states it is a physics rendering, not raw SAR.
            #expect(record.items.contains { $0.label == "MODELED" && $0.detail.contains("NOT a raw") })
        }
    }

    @Test func flagshipDossiersHaveSixSections() throws {
        for id in ["central-valley", "norfolk"] {
            let record = try #require(EvidenceRecord.load(eventId: id))
            let dossier = try #require(record.dossier)
            #expect(dossier.sections.count == 6)
            #expect(dossier.sections.map(\.title) == [
                "What we observed", "What it means", "Why it matters",
                "Possible drivers", "What the evidence cannot tell us",
                "What to investigate next",
            ])
            #expect(record.interpretation != nil)
        }
    }

    @Test func geologyEventsClaimNoClimateLink() {
        for id in ["svartsengi", "kilauea", "san-andreas", "campi-flegrei", "kahramanmaras"] {
            let record = EvidenceRecord.load(eventId: id)
            #expect(record?.climateLink == "none-claimed")
            #expect(record?.climateNote?.isEmpty == false)
            #expect(record?.dossier == nil)
        }
    }

    @Test func evidenceRecordJSONRoundTrip() throws {
        let record = try #require(EvidenceRecord.load(eventId: "norfolk"))
        let data = try record.exportJSON()
        let decoded = try JSONDecoder().decode(EvidenceRecord.self, from: data)
        #expect(decoded == record)
    }

    // MARK: - Hashing & manifest

    @Test func sha256KnownVector() {
        let digest = SHA256.hash(data: Data("abc".utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        #expect(hex == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func bundledRecordsMatchManifest() throws {
        let manifest = try #require(EvidenceManifest.load())
        #expect(manifest.algorithm == "sha256")
        #expect(manifest.records.count == EventCatalog.all.count)
        for event in EventCatalog.all {
            #expect(manifest.entry(for: event.id) != nil, "\(event.id) missing from manifest")
        }

        for event in EventCatalog.all {
            let integrity = try #require(EvidenceIntegrity.verify(eventId: event.id))
            #expect(integrity.digestMatch,
                    "\(event.id): recomputed digest does not match the anchored manifest")
            #expect(integrity.anchored)
        }
    }

    // MARK: - OpenTimestamps proof parsing

    /// Builds a minimal .ots byte stream: magic + SHA-256 file-op + timestamp.
    private func makeOTS(digest: Data, tail: [UInt8]) -> Data {
        var data = OTSProof.magic
        data.append(0x08)
        data.append(digest)
        data.append(contentsOf: tail)
        return data
    }

    @Test func parsesPendingProof() throws {
        let digest = Data(SHA256.hash(data: Data("fringe-test".utf8)))
        // append(16-byte nonce) → sha256 → pending attestation
        let nonce: [UInt8] = Array(repeating: 0x42, count: 16)
        let uri = "https://alice.btc.calendar.opentimestamps.org"
        var tail: [UInt8] = [0xf0, 0x10]
        tail += nonce
        tail += [0x08]                                  // sha256 op
        tail += [0x00]                                  // final attestation tag
        tail += Array(Data(hexString: "83dfe30d2ef90c8e"))
        tail += [UInt8(uri.utf8.count)] + Array(uri.utf8)

        let proof = try OTSProof(data: makeOTS(digest: digest, tail: tail))
        #expect(proof.digest == digest)
        #expect(proof.pendingCalendar == uri)
        #expect(proof.bitcoin == nil)
    }

    @Test func parsesConfirmedBitcoinProof() throws {
        let digest = Data(SHA256.hash(data: Data("fringe-test-2".utf8)))
        let uri = "https://a.pool.opentimestamps.org"
        var tail: [UInt8] = [0xf0, 0x10]
        tail += [UInt8](repeating: 0x11, count: 16)
        tail += [0x08]                                  // sha256 op (nonce preimage)
        tail += [0xff, 0x00]                            // non-final attestation branch
        tail += Array(Data(hexString: "83dfe30d2ef90c8e"))
        tail += [UInt8(uri.utf8.count)] + Array(uri.utf8)
        // Final: bitcoin attestation, height 128 → varint 0x80 0x01
        tail += [0x00]
        tail += Array(Data(hexString: "0588960d73d71901"))
        tail += [0x80, 0x01]

        let proof = try OTSProof(data: makeOTS(digest: digest, tail: tail))
        #expect(proof.bitcoin?.height == 128)
        #expect(proof.pendingCalendar == uri)
    }

    @Test func rejectsCorruptedProof() {
        let digest = Data(SHA256.hash(data: Data("fringe-test-3".utf8)))
        var data = makeOTS(digest: digest, tail: [0x00])
        data += Array(Data(hexString: "83dfe30d2ef90c8e").prefix(4)) // truncated attestation
        #expect(throws: (any Error).self) { try OTSProof(data: data) }
    }

    @Test func bundledProofsParseAndMatchDigest() throws {
        for event in EventCatalog.all {
            guard let data = EvidenceRecord.bundledData(eventId: event.id) else {
                continue
            }
            let digest = Data(SHA256.hash(data: data))
            let state = EvidenceIntegrity.anchorState(eventId: event.id, digest: digest)
            switch state {
            case .missing:
                Issue.record("\(event.id): bundled .ots proof missing or digest mismatch")
            case .pending:
                break // honest state until Bitcoin confirmation
            case .confirmed:
                break
            }
        }
    }

    // MARK: - Bundled GNSS (real data)

    @Test func centralValleyGNSSShowsDroughtSubsidence() throws {
        let series = GNSSSeries.load(eventId: "central-valley")
        #expect(series.count == 2)
        #expect(Set(series.map(\.station)) == ["P304", "P307"])
        for s in series {
            let up = try #require(s.lastSample)[3]
            #expect(up < -100, "\(s.station): expected ≥ 100 mm of drought-era subsidence, got \(up) mm")
        }
    }

    @Test func gnssSamplesAreWeeklyMeans() throws {
        let series = GNSSSeries.load(eventId: "kilauea")
        let uwev = try #require(series.first { $0.station == "UWEV" })
        #expect(uwev.samples.count > 40)
        #expect(uwev.samples.allSatisfy { $0.count == 4 })
    }

    // MARK: - Grounded Q&A degradation

    @Test func askServiceDegradesGracefullyWithoutConfig() async {
        let qa = EventQAService()
        guard let record = EvidenceRecord.load(eventId: "norfolk") else {
            Issue.record("norfolk record missing")
            return
        }
        if qa.isConfigured {
            // Config present in a hosted run — nothing to assert about failure modes.
            return
        }
        await #expect(throws: EventQAService.QAError.notConfigured) {
            try await qa.ask(question: "Why is Norfolk sinking?", record: record)
        }
    }
}

private extension Data {
    init(hexString: String) {
        self.init()
        var iterator = hexString.indices.makeIterator()
        while let i = iterator.next(), let j = iterator.next() {
            let b = UInt8(hexString[i...j], radix: 16)!
            append(b)
        }
    }
}
