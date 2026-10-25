import Foundation
import Observation

/// One reading from a Fringe Live Ground Station (ESP32 + MPU-6050).
struct LiveSample: Identifiable, Equatable {
    let id = UUID()
    let at: Date
    let uptime: TimeInterval
    let tiltX: Double?
    let tiltY: Double?
    let temperature: Double?

    var hasMotion: Bool { tiltX != nil && tiltY != nil }

    /// Combined tilt magnitude in degrees — what the sparkline plots.
    var tiltMagnitude: Double? {
        guard let x = tiltX, let y = tiltY else { return nil }
        return (x * x + y * y).squareRoot()
    }
}

/// Connection lifecycle of the Live Ground Station card.
enum LiveStationPhase: Equatable {
    case idle
    case searching
    case connected(hasSensor: Bool)
    case failed(String)
    case lost
}

/// Wire format served by the ground station sketch at "/".
nonisolated struct StationPayload: Decodable {
    let station: String?
    let fw: Int?
    let uptime_s: Double?
    let sensor: Bool?
    let tilt_x: Double?
    let tilt_y: Double?
    let temp_c: Double?

    var hasSensor: Bool { sensor ?? false }

    func sample() -> LiveSample {
        LiveSample(
            at: Date(),
            uptime: uptime_s ?? 0,
            tiltX: hasSensor ? tilt_x : nil,
            tiltY: hasSensor ? tilt_y : nil,
            temperature: hasSensor ? temp_c : nil
        )
    }
}

/// Streams live tilt readings from a Fringe ground station on the local network.
/// One poll loop per connection (~2 Hz); all state is main-actor isolated so
/// SwiftUI observes it directly. Nothing is fabricated: until a station answers,
/// the phase says so.
@Observable
@MainActor
final class LiveStationService {
    private(set) var phase: LiveStationPhase = .idle
    private(set) var samples: [LiveSample] = []
    private(set) var stationHost: String?

    /// The mDNS name the sketch registers.
    static let defaultHost = "fringe-station.local"
    private static let maxSamples = 170

    private var pollTask: Task<Void, Never>?
    private var everConnected = false
    private var failedAttempts = 0

    /// Last host used, pre-filled in the connect sheet.
    var lastHost: String {
        get { UserDefaults.standard.string(forKey: "liveStation.lastHost") ?? Self.defaultHost }
        set { UserDefaults.standard.set(newValue, forKey: "liveStation.lastHost") }
    }

    var latest: LiveSample? { samples.last }

    var isConnected: Bool {
        if case .connected = phase { return true }
        return false
    }

    /// Connects and starts polling. Accepts "fringe-station.local", a raw IP, or a pasted URL.
    func connect(to rawHost: String) {
        guard let host = Self.sanitizeHost(rawHost) else {
            phase = .failed("That doesn't look like an address. Try the IP printed on the station's Serial Monitor.")
            return
        }
        disconnect()
        stationHost = host
        lastHost = host
        phase = .searching
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    /// Stops polling and forgets the session, samples included.
    func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        stationHost = nil
        everConnected = false
        failedAttempts = 0
        samples = []
        phase = .idle
    }

    /// Strips scheme/trailing slashes and allows only host-safe characters.
    static func sanitizeHost(_ raw: String) -> String? {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for scheme in ["http://", "https://"] where host.lowercased().hasPrefix(scheme) {
            host = String(host.dropFirst(scheme.count))
        }
        while host.hasSuffix("/") { host.removeLast() }
        guard !host.isEmpty,
              host.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == ":" || $0 == "%" })
        else { return nil }
        return host.lowercased()
    }

    private func pollLoop() async {
        while let host = stationHost, !Task.isCancelled {
            var request = URLRequest(url: URL(string: "http://\(host)/")!)
            request.timeoutInterval = 2.5
            request.cachePolicy = .reloadIgnoringLocalCacheData
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let payload = try JSONDecoder().decode(StationPayload.self, from: data)
                everConnected = true
                failedAttempts = 0
                samples.append(payload.sample())
                if samples.count > Self.maxSamples {
                    samples.removeFirst(samples.count - Self.maxSamples)
                }
                phase = .connected(hasSensor: payload.hasSensor)
            } catch {
                if everConnected {
                    phase = .lost
                } else {
                    failedAttempts += 1
                    if failedAttempts >= 4 {
                        phase = .failed("No station answered at \(host). Check the address — both devices must be on the same WiFi.")
                        return
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}
