import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                AuthenticationView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.isAuthenticated)
        .environment(\.locale, Locale(identifier: session.appLanguage.localeIdentifier))
        .contrast(session.prefersHighContrast ? 1.18 : 1)
        .modifier(PreferredTextSizeModifier(enabled: session.prefersLargeText))
    }
}

private struct PreferredTextSizeModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.dynamicTypeSize(.accessibility1)
        } else {
            content
        }
    }
}
