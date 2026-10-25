import SwiftUI

/// Grounded "Ask this event" Q&A. Context is strictly the event's bundled
/// evidence record; answers must cite it and refuse invention. Degrades to a
/// pointer at the pre-generated interpretation when offline or unavailable.
struct AskEventSheet: View {
    let event: DeformationEvent

    @State private var question = ""
    @State private var answer: String?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var qa = EventQAService()
    @Environment(\.dismiss) private var dismiss

    private var suggestions: [String] {
        switch event.kind {
        case .subsidence:
            return ["What caused this subsidence?", "How fast is it happening, and how confident are we?", "What can't this evidence tell us?"]
        case .uplift, .flank:
            return ["What is driving this motion?", "How confident are the cited measurements?", "What can't this evidence tell us?"]
        case .faultSlip:
            return ["What does this fault motion mean?", "How was this measured?", "What can't this evidence tell us?"]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ASK THIS EVENT").kicker(Theme.lateral)
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text("Answers come only from this event's hashed evidence record.")
                        .font(.caption2)
                        .foregroundStyle(Theme.sage)
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
                VStack(alignment: .leading, spacing: 14) {
                    if let answer {
                        answerCard(answer)
                    } else if let errorText {
                        errorCard(errorText)
                    } else {
                        idleCard
                    }
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Theme.accent)
                            Text("Reading the evidence record…")
                                .font(.caption)
                                .foregroundStyle(Theme.sage)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)

            inputBar
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.canvas)
        .background(SignalBackground().opacity(0.4).allowsHitTesting(false))
        .task {
            if answer == nil, let record = EvidenceRecord.load(eventId: event.id) {
                question = event.id == "central-valley"
                    ? "What caused this drought subsidence?"
                    : event.id == "norfolk"
                    ? "How does coastal sinking compound sea-level rise?"
                    : "What is driving this deformation?"
                answer = record.interpretation?.studentText ?? record.dossier?.headline
            }
        }
    }

    private var idleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRY ASKING").kicker()
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    question = suggestion
                    ask()
                } label: {
                    HStack {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(Theme.text)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Theme.surfaceRaised, in: .rect(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            if !qa.isConfigured {
                Text("The live Q&A needs a connection — the pre-generated interpretation in the climate dossier below works offline.")
                    .font(.caption2)
                    .foregroundStyle(Theme.sage.opacity(0.9))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }

    private func answerCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.fill")
                    .font(.caption.weight(.bold))
                Text("GROUNDED ANSWER").kicker(Theme.lateral)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.text.opacity(0.92))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Theme.stroke)
            Text("Grounded on the event's evidence record — same JSON that is hashed into the Bitcoin anchor. The assistant is instructed to refuse unsupported claims.")
                .font(.caption2)
                .foregroundStyle(Theme.sage.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
    }

    private func errorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "wifi.slash")
                    .font(.caption.weight(.bold))
                Text("UNAVAILABLE").kicker(Theme.amber)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.text.opacity(0.9))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                errorText = nil
            } label: {
                Text("Ask again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fringeCard()
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.amber.opacity(0.3), lineWidth: 1)
        )
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about this event…", text: $question, axis: .vertical)
                .lineLimit(1...3)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.surface, in: .rect(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
                .onSubmit { ask() }
            Button {
                ask()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isLoading ? Theme.sage : Theme.accent)
            }
            .disabled(isLoading)
            .accessibilityLabel("Send question")
        }
    }

    private func ask() {
        guard let record = EvidenceRecord.load(eventId: event.id) else {
            errorText = "No evidence record is bundled for this event."
            return
        }
        isLoading = true
        errorText = nil
        answer = nil
        Task {
            defer { isLoading = false }
            do {
                let result = try await qa.ask(question: question, record: record)
                answer = result.text
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
