import Foundation

/// Grounded "Ask this event" Q&A.
///
/// The model's ONLY context is the event's bundled evidence record — the same
/// hashed, anchored JSON shown in the Evidence & Provenance panel. The service
/// instructs the model to cite record content, mark uncertainty, and refuse
/// anything the record does not support. Fully offline-degradable: callers show
/// the pre-generated interpretation when this fails.
nonisolated final class EventQAService: @unchecked Sendable {
    struct Answer: Sendable {
        let text: String
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isConfigured: Bool {
        !Config.AI_GATEWAY_URL.isEmpty && !Config.AI_GATEWAY_SECRET_KEY.isEmpty
    }

    func ask(question: String, record: EvidenceRecord) async throws -> Answer {
        guard isConfigured else { throw QAError.notConfigured }
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw QAError.emptyQuestion
        }

        let context = String(data: try record.exportJSON(), encoding: .utf8) ?? ""
        let system = """
        You are the grounded Q&A assistant inside Fringe, a radar-interferometry
        (InSAR) field app. You answer questions about ONE deformation event, using
        ONLY the evidence record below. The user has already seen the app's
        visualization.

        Rules:
        - Ground every claim in the record. Cite the section, item, or source you
          used, e.g. "(dossier: What we observed)" or "(source: Buzzanga et al., 2020)".
        - If the record does not answer the question, say so plainly and suggest
          what to investigate next. NEVER invent numbers, rates, dates, or citations.
        - Keep the measured/modeled distinction: the app's interferogram is a
          physics rendering tuned to published figures, NOT raw SAR pixels. Say
          so if asked about the image.
        - Mark uncertainty explicitly (± values, confidence levels) when present.
        - Reply in at most 150 words, plain language, no markdown headers.

        Evidence record (JSON):
        \(context)
        """

        let url = URL(string: "\(Config.AI_GATEWAY_URL)/v2/vercel/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.AI_GATEWAY_SECRET_KEY)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": "anthropic/claude-haiku-5.5",
            "temperature": 0.2,
            "max_tokens": 700,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": question],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await sendWithRetry(request, session: session)

        struct ChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw ProxyError.noData
        }
        return Answer(text: text)
    }

    enum QAError: LocalizedError {
        case notConfigured
        case emptyQuestion

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                "Ask-this-event needs a network connection. Meanwhile, the pre-generated interpretation in the climate dossier is always available offline."
            case .emptyQuestion:
                "Type a question first."
            }
        }
    }
}
