import SwiftUI

struct AIGuideView: View {
    let context: AIGuideContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chat = AIGuideChatService()
    @State private var draft = ""
    @State private var requestTask: Task<Void, Never>?
    @FocusState private var isComposerFocused: Bool

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chat.isLoading && !API.appKey.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        guideHeader
                        if API.appKey.isEmpty { configurationNotice }
                        ForEach(chat.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                        if chat.isLoading { thinkingBubble.id("thinking") }
                        if let error = chat.errorMessage { errorBubble(error).id("error") }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Theme.surfaceLow)
                .onChange(of: chat.messages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: chat.isLoading) { _, _ in scrollToBottom(proxy) }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .navigationTitle("AI Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { requestTask?.cancel() }
    }

    private var guideHeader: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .frame(width: 44, height: 44)
                .background(Theme.goldLight.opacity(0.35), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text("Ask about \(context.monumentName)")
                    .font(.headline).foregroundStyle(Theme.ink)
                Text("Your question will use the guide content for \(context.checkpointName).")
                    .font(.subheadline).foregroundStyle(Theme.mutedInk)
                Text("AI responses may contain mistakes. Check important details with venue staff.")
                    .font(.caption).foregroundStyle(Theme.mutedInk.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .heritageCard()
    }

    private var configurationNotice: some View {
        Label(
            "AI Guide needs MARAUDERS_APP_KEY in Secrets.xcconfig before it can answer questions.",
            systemImage: "key.fill"
        )
        .font(.subheadline).foregroundStyle(Theme.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func messageBubble(_ message: AIGuideChatService.Message) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 44) }
            Text(message.text)
                .font(.body)
                .foregroundStyle(message.role == .user ? .white : Theme.ink)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(
                    message.role == .user ? Theme.primary : Theme.surface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    if message.role == .guide {
                        RoundedRectangle(cornerRadius: 18).stroke(Theme.outline.opacity(0.55))
                    }
                }
            if message.role == .guide { Spacer(minLength: 44) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(message.role == .user ? "You: \(message.text)" : "AI Guide: \(message.text)")
    }

    private var thinkingBubble: some View {
        HStack(spacing: 9) {
            ProgressView().tint(Theme.primary)
            Text("Looking through the local guide…")
                .font(.subheadline).foregroundStyle(Theme.mutedInk)
            Spacer()
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func errorBubble(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline).foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask your guide…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($isComposerFocused)
                .submitLabel(.send)
                .onSubmit { send() }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Theme.surfaceContainer, in: RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("aiGuideComposer")
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canSend ? Theme.primary : Theme.mutedInk.opacity(0.35), in: Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Send question")
            .accessibilityIdentifier("aiGuideSendButton")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private func send() {
        guard canSend else { return }
        let question = draft
        draft = ""
        requestTask?.cancel()
        requestTask = Task { await chat.send(question, context: context) }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(Motion.quick) {
            if chat.isLoading {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let message = chat.messages.last {
                proxy.scrollTo(message.id, anchor: .bottom)
            } else if chat.errorMessage != nil {
                proxy.scrollTo("error", anchor: .bottom)
            }
        }
    }
}
