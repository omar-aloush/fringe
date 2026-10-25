import CryptoKit
import Foundation

/// Minimal OpenTimestamps `.ots` proof parser, matching the serialization used
/// by python-opentimestamps 0.4.x (the reference implementation).
///
/// Grammar (per timestamp level, message M):
/// - zero or more non-final elements, each `0xff` + tag + payload, then one
///   final element without the `0xff` prefix;
/// - tag `0x00` = attestation (8-byte tag + varbytes payload);
/// - tag `0xf0` = append (varbytes arg, M' = M + arg), `0xf1` = prepend
///   (M' = arg + M), `0x08` = SHA-256 (M' = SHA256(M)).
///
/// Attestation tags: pending `83dfe30d2ef90c8e` (payload = calendar URI),
/// Bitcoin `0588960d73d71901` (payload = block height varint; the attested
/// message is the block's Merkle root).
///
/// The in-app check establishes that the proof links the record digest into a
/// Bitcoin block and surfaces the height for one-tap independent confirmation
/// in a block explorer. Full cryptographic verification (Merkle path +
/// block-header re-computation) remains the job of the `ots` CLI, as stated
/// in the UI.
nonisolated enum OTSProofError: Error {
    case truncated
    case badMagic
    case unsupportedOp(UInt8)
    case unsupportedAttestation
}

nonisolated enum OTSAttestation: Hashable, Sendable {
    case pending(calendarURI: String)
    case bitcoin(height: Int)

    var height: Int? {
        if case let .bitcoin(height) = self { return height }
        return nil
    }
}

nonisolated struct OTSProof: Sendable {
    static let magic = Data([
        0x00, 0x4F, 0x70, 0x65, 0x6E, 0x54, 0x69, 0x6D, 0x65, 0x73, 0x74, 0x61,
        0x6D, 0x70, 0x73, 0x00, 0x00, 0x50, 0x72, 0x6F, 0x6F, 0x66, 0x00,
        0xBF, 0x89, 0xE2, 0xE8, 0x84, 0xE8, 0x92, 0x94, 0x01,
    ])

    /// The digest at the head of the proof (SHA-256 of the timestamped file).
    let digest: Data
    let attestations: [OTSAttestation]

    var pendingCalendar: String? {
        for case let .pending(uri) in attestations { return uri }
        return nil
    }

    var bitcoin: OTSAttestation? {
        attestations.first { if case .bitcoin = $0 { return true } else { return false } }
    }

    // MARK: Parsing

    init(data: Data) throws {
        let magic = Self.magic
        guard data.count > magic.count + 32, data.prefix(magic.count) == magic else {
            throw OTSProofError.badMagic
        }
        // File-hash op tag: 0x08 = SHA-256.
        guard data[magic.count] == 0x08 else { throw OTSProofError.unsupportedOp(data[magic.count]) }
        digest = data.subdata(in: (magic.count + 1)..<(magic.count + 33))

        var attestations: [OTSAttestation] = []
        try Self.parseTimestamp(data, pos: magic.count + 33, end: data.count, message: digest, into: &attestations)
        guard !attestations.isEmpty else { throw OTSProofError.truncated }
        self.attestations = attestations
    }

    private static func parseTimestamp(
        _ data: Data, pos: Int, end: Int, message: Data, into out: inout [OTSAttestation]
    ) throws {
        var pos = pos
        while pos < end {
            let lead = data[pos]
            pos += 1
            if lead != 0xff {
                // Final element at this level.
                try parseElement(data, tag: lead, pos: &pos, end: end, message: message, into: &out)
                return
            }
            // Non-final element: next byte is the tag.
            guard pos < end else { throw OTSProofError.truncated }
            let tag = data[pos]
            pos += 1
            try parseElement(data, tag: tag, pos: &pos, end: end, message: message, into: &out)
        }
        throw OTSProofError.truncated
    }

    private static func parseElement(
        _ data: Data, tag: UInt8, pos: inout Int, end: Int, message: Data, into out: inout [OTSAttestation]
    ) throws {
        switch tag {
        case 0x00: // attestation follows
            try parseAttestation(data, pos: &pos, end: end, message: message, into: &out)

        case 0xf0: // append
            let arg = try readVarbytes(data, pos: &pos, end: end)
            try parseTimestamp(data, pos: pos, end: end, message: message + arg, into: &out)
            return // sub-timestamp consumed the rest of this level

        case 0xf1: // prepend
            let arg = try readVarbytes(data, pos: &pos, end: end)
            try parseTimestamp(data, pos: pos, end: end, message: arg + message, into: &out)
            return

        case 0x08: // SHA-256
            let next = Data(SHA256.hash(data: message))
            try parseTimestamp(data, pos: pos, end: end, message: next, into: &out)
            return

        default:
            throw OTSProofError.unsupportedOp(tag)
        }
    }

    private static func parseAttestation(
        _ data: Data, pos: inout Int, end: Int, message: Data, into out: inout [OTSAttestation]
    ) throws {
        guard end - pos >= 8 else { throw OTSProofError.truncated }
        let tag = data.subdata(in: pos..<(pos + 8))
        pos += 8

        if tag == Data([0x83, 0xDF, 0xE3, 0x0D, 0x2E, 0xF9, 0x0C, 0x8E]) { // pending
            let payload = try readVarbytes(data, pos: &pos, end: end)
            let uri = String(data: payload, encoding: .utf8) ?? ""
            out.append(.pending(calendarURI: uri))
        } else if tag == Data([0x05, 0x88, 0x96, 0x0D, 0x73, 0xD7, 0x19, 0x01]) { // bitcoin
            // BitcoinBlockHeaderAttestation serializes a bare varuint height —
            // the attested digest is the block's Merkle root.
            let (height, next) = readVarint(data, at: pos)
            pos = next
            out.append(.bitcoin(height: Int(height)))
        } else {
            // Litecoin / Ethereum / unknown — recognized, not acted on.
            out.append(.pending(calendarURI: "secondary attestation"))
        }
    }

    private static func readVarbytes(_ data: Data, pos: inout Int, end: Int) throws -> Data {
        let (length, bytes) = readVarint(data, at: pos)
        pos += bytes
        guard pos + Int(length) <= end else { throw OTSProofError.truncated }
        let value = data.subdata(in: pos..<(pos + Int(length)))
        pos += Int(length)
        return value
    }

    private static func readVarint(_ data: Data, at pos: Int) -> (UInt64, Int) {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var bytes = 0
        var index = pos
        while index < data.count {
            let b = data[index]
            index += 1
            bytes += 1
            value |= UInt64(b & 0x7f) << shift
            if b & 0x80 == 0 { break }
            shift += 7
        }
        return (value, bytes)
    }
}
