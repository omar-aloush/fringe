import Foundation

/// Error type for calls to the AI proxy gateway.
enum ProxyError: LocalizedError {
    case authError
    case insufficientBalance
    case payloadTooLarge
    case rateLimited
    case serverError(Int)
    case clientError(Int)
    case noData

    var errorDescription: String? {
        switch self {
        case .authError:           "AI features are currently unavailable. Please restart the app."
        case .insufficientBalance: "AI features are temporarily unavailable. Please try again later."
        case .payloadTooLarge:     "Image is too large. Please try a smaller photo."
        case .rateLimited:         "Too many requests. Please wait a moment and try again."
        case .serverError:         "Something went wrong. Please try again."
        case .clientError:         "Something went wrong. Please try again."
        case .noData:              "No response from the AI service. Please try again."
        }
    }
}

/// `Retry-After` in seconds, per RFC 7231 §7.1.3 (delta-seconds or HTTP-date).
func retryAfterSeconds(from response: HTTPURLResponse) -> Double? {
    guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
    if let seconds = Double(value.trimmingCharacters(in: .whitespaces)) {
        return max(0, seconds)
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    if let date = formatter.date(from: value) {
        return max(0, date.timeIntervalSinceNow)
    }
    return nil
}

func exponentialDelay(attempt: Int) -> Double {
    let base = pow(2.0, Double(attempt))
    let jitter = Double.random(in: 0...0.5)
    return base + jitter
}

/// Single retry wrapper for POST requests to the AI gateway:
/// max 3 attempts, `Retry-After` precedence, one idempotency key per request.
func sendWithRetry(
    _ request: URLRequest,
    maxAttempts: Int = 3,
    session: URLSession = .shared
) async throws -> (Data, HTTPURLResponse) {
    var req = request
    if req.value(forHTTPHeaderField: "idempotency-key") == nil {
        req.setValue(UUID().uuidString, forHTTPHeaderField: "idempotency-key")
    }

    var lastTransportError: Error?

    for attempt in 0..<maxAttempts {
        let isLastAttempt = attempt == maxAttempts - 1

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw ProxyError.serverError(0)
            }

            switch http.statusCode {
            case 200...299:
                return (data, http)
            case 401:
                throw ProxyError.authError
            case 402:
                throw ProxyError.insufficientBalance
            case 413:
                throw ProxyError.payloadTooLarge
            case 429:
                if isLastAttempt { throw ProxyError.rateLimited }
                let wait = retryAfterSeconds(from: http) ?? exponentialDelay(attempt: attempt)
                try await Task.sleep(for: .seconds(wait))
                continue
            case 500...599:
                if isLastAttempt { throw ProxyError.serverError(http.statusCode) }
                let wait = retryAfterSeconds(from: http) ?? exponentialDelay(attempt: attempt)
                try await Task.sleep(for: .seconds(wait))
                continue
            default:
                throw ProxyError.clientError(http.statusCode)
            }
        } catch let error as ProxyError {
            throw error
        } catch {
            lastTransportError = error
            if isLastAttempt { throw error }
            try await Task.sleep(for: .seconds(exponentialDelay(attempt: attempt)))
            continue
        }
    }

    throw lastTransportError ?? ProxyError.serverError(0)
}
