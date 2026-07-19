import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLaunching = true

    var body: some View {
        ZStack {
            if isLaunching {
                LaunchBrandView()
                    .transition(reduceMotion ? .identity : .move(edge: .leading))
                    .zIndex(1)
            } else {
                Group {
                    if session.isAuthenticated {
                        MainTabView()
                            .transition(Motion.subtleTransition(reduceMotion: reduceMotion))
                    } else {
                        AuthenticationView()
                            .transition(.opacity)
                    }
                }
                .transition(reduceMotion ? .identity : .move(edge: .trailing))
            }
        }
        .animation(Motion.change(reduceMotion: reduceMotion), value: session.isAuthenticated)
        .task {
            guard isLaunching else { return }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 450 : 900))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .smooth(duration: 0.5)) {
                isLaunching = false
            }
        }
        .environment(\.locale, Locale(identifier: session.appLanguage.localeIdentifier))
        .contrast(session.prefersHighContrast ? 1.18 : 1)
        .modifier(PreferredTextSizeModifier(enabled: session.prefersLargeText))
    }
}

private struct LaunchBrandView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.surface, Theme.surfaceContainer, Theme.goldLight.opacity(0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("MaraudersLogo")
                    .resizable().scaledToFit()
                    .frame(width: 82, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .shadow(color: Theme.primary.opacity(0.18), radius: 14, y: 8)
                Text("MARAUDERS")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Theme.primary)
                Text("STORIES IN EVERY STEP")
                    .font(.caption.bold()).tracking(1.4)
                    .foregroundStyle(Theme.gold)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Marauders, stories in every step")
    }
}

private struct PreferredTextSizeModifier: ViewModifier {
    let enabled: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled, !dynamicTypeSize.isAccessibilitySize {
            content.dynamicTypeSize(.accessibility1)
        } else {
            content
        }
    }
}
