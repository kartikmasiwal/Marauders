import SwiftUI

@MainActor
final class GuideChatStore: ObservableObject {
    struct Message: Identifiable, Equatable {
        enum Role { case visitor, guide, error }
        let id = UUID()
        let role: Role
        let text: String
    }

    @Published private(set) var messages: [Message] = []
    @Published private(set) var isThinking = false

    let monumentID: String
    let checkpointID: String
    let language: String
    private let engine: any AnswerEngine

    init(monumentID: String, checkpointID: String, language: String, engine: any AnswerEngine = HybridAnswerEngine()) {
        self.monumentID = monumentID
        self.checkpointID = checkpointID
        self.language = language
        self.engine = engine
    }

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        messages.append(Message(role: .visitor, text: text))
        isThinking = true
        Task {
            do {
                let response = try await engine.answer(
                    text: text, audioBase64: nil,
                    checkpointId: checkpointID, monumentId: monumentID,
                    lang: language, skipAudio: true
                )
                messages.append(Message(role: .guide, text: response.text))
            } catch {
                messages.append(Message(role: .error, text: error.localizedDescription))
            }
            isThinking = false
        }
    }
}

struct GuideChatView: View {
    @StateObject private var store: GuideChatStore
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    init(monumentID: String, checkpointID: String, language: String) {
        _store = StateObject(wrappedValue: GuideChatStore(monumentID: monumentID, checkpointID: checkpointID, language: language))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            intro
                            ForEach(store.messages) { bubble($0) }
                            if store.isThinking {
                                HStack { ProgressView(); Text("Guide is thinking…").font(.subheadline).foregroundStyle(Theme.mutedInk) }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: store.messages) { _, messages in
                        if let last = messages.last { withAnimation(.snappy) { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                inputBar
            }
            .background(Theme.surfaceLow)
            .navigationTitle("Ask the Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("guideChatDone")
                }
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 6) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.title2).foregroundStyle(Theme.gold)
            Text("Type any question about this place — answers arrive as fast text, no audio.")
                .font(.footnote).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
            if FoundationModelsAnswerEngine.isUsable {
                Label("Answering on-device", systemImage: "cpu.fill")
                    .font(.caption2.bold()).foregroundStyle(Theme.teal)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }

    @ViewBuilder
    private func bubble(_ message: GuideChatStore.Message) -> some View {
        HStack {
            if message.role == .visitor { Spacer(minLength: 40) }
            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(message.role == .visitor ? .white : Theme.ink)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    message.role == .visitor ? Theme.primary : (message.role == .error ? Theme.primary.opacity(0.12) : Theme.surface),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    if message.role != .visitor {
                        RoundedRectangle(cornerRadius: 18).stroke(Theme.outline.opacity(0.6))
                    }
                }
            if message.role != .visitor { Spacer(minLength: 40) }
        }
        .id(message.id)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about this place…", text: $draft, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(Theme.outline.opacity(0.7)) }
                .onSubmit(submit)
                .accessibilityIdentifier("guideChatInput")
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty || store.isThinking ? Theme.outline : Theme.primary)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || store.isThinking)
            .accessibilityIdentifier("guideChatSend")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func submit() {
        store.send(draft)
        draft = ""
    }
}
