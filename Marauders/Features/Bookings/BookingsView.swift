import SwiftUI

struct BookingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.surfaceLow.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header.oneTimeStaggeredReveal(0)
                        ForEach(MockData.bookings) { booking in TourTicketCard(booking: booking) }
                    }.padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TourBooking.self) { TourPreparationView(booking: $0) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR JOURNEYS").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(Theme.gold)
                    Text("My Tours").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(Theme.primary)
                }
                Spacer()
                Image(systemName: "ticket.fill").foregroundStyle(Theme.primary).padding(12).background(Theme.surfaceHigh, in: Circle())
            }
            Text("Download once, then explore without a network connection.").foregroundStyle(Theme.mutedInk)
        }
    }
}

private struct TourTicketCard: View {
    let booking: TourBooking

    var body: some View {
        VStack(spacing: 0) {
            Image(booking.imageName).resizable().scaledToFill().frame(height: 165).clipped()
                .allowsHitTesting(false).accessibilityHidden(true)
                .overlay(alignment: .topLeading) {
                    Label(booking.packageAvailable ? "OFFLINE PACKAGE" : "DOWNLOAD AVAILABLE", systemImage: booking.packageAvailable ? "checkmark.icloud.fill" : "arrow.down.circle.fill")
                        .font(.caption2.bold()).tracking(0.7).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 7).background((booking.packageAvailable ? Theme.teal : Theme.gold).opacity(0.92), in: Capsule()).padding(14)
                }
            VStack(alignment: .leading, spacing: 12) {
                Text(booking.name).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
                Label(booking.city, systemImage: "mappin.and.ellipse")
                Divider().overlay(Theme.outline.opacity(0.6))
                NavigationLink(value: booking) {
                    HStack { Text(booking.packageAvailable ? "Prepare Tour" : "Download Tour").fontWeight(.semibold); Spacer(); Image(systemName: "arrow.down.to.line.compact") }
                        .foregroundStyle(.white).padding(.horizontal, 18).frame(height: 48).background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
                }.accessibilityIdentifier("viewTicket_\(booking.packageID.replacingOccurrences(of: "_", with: "-"))")
            }.font(.subheadline).foregroundStyle(Theme.mutedInk).padding(18)
        }
        .background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Theme.outline.opacity(0.7)) }
        .shadow(color: Theme.ink.opacity(0.07), radius: 12, y: 6)
    }
}

struct TourPreparationView: View {
    let booking: TourBooking
    @Environment(AppSession.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var store = PackageStore()
    @State private var installed: InstalledTour?
    @State private var selectedTourLanguage = AppLanguage.englishUK
    @State private var errorMessage: String?
    @State private var started = false
    @State private var isStartingTour = false

    var body: some View {
        Group {
            if isStartingTour {
                TourLaunchLoadingView(booking: booking, language: selectedTourLanguage)
                    .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 0.98)))
            } else if started, let installed {
                TourContainerView(booking: booking, installed: installed, language: selectedTourLanguage.contentLanguageCode)
                    .transition(.opacity.combined(with: reduceMotion ? .identity : .scale(scale: 1.015)))
            } else {
                preparation
                    .transition(.opacity)
            }
        }
        .navigationTitle(started || isStartingTour ? "" : booking.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(started || isStartingTour ? .hidden : .visible, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if installed != nil, !started, !isStartingTour {
                startTourFooter
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(\.locale, Locale(identifier: selectedTourLanguage.localeIdentifier))
        .task { await prepare() }
    }

    private var preparation: some View {
        ZStack {
            Theme.surfaceLow.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                Image(booking.imageName).resizable().scaledToFill().frame(height: 210).clipped().clipShape(RoundedRectangle(cornerRadius: 26))
                    .allowsHitTesting(false).accessibilityHidden(true)
                if let installed {
                    Image(systemName: "checkmark.icloud.fill").font(.system(size: 42)).foregroundStyle(Theme.teal)
                    Text("Tour ready offline").font(.title2.bold())
                    Text(installed.package.monument.overview.v(selectedTourLanguage.contentLanguageCode)).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Guide language").font(.headline).foregroundStyle(Theme.ink)
                        Picker("Guide language", selection: $selectedTourLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(verbatim: language.title).tag(language)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 180 : 128)
                        .clipped()
                        .accessibilityLabel("Guide language")
                        .accessibilityHint("Swipe up or down to choose the tour language.")
                        .accessibilityIdentifier("languagePicker")
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 18).stroke(Theme.outline.opacity(0.7)) }

                } else if let errorMessage {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 40)).foregroundStyle(Theme.primary)
                    Text(errorMessage).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
                    Button("Retry Download") { Task { await prepare(forceRemote: true) } }.buttonStyle(PrimaryButtonStyle())
                } else {
                    ProgressView(value: store.downloadProgress)
                    Text(store.isDownloading ? "Preparing offline package…" : "Checking tour package…").foregroundStyle(Theme.mutedInk)
                }
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var startTourFooter: some View {
        VStack(spacing: 9) {
            Label("Please use headphones for a better experience.", systemImage: "headphones")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.mutedInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
            Button("Start Tour") { startTour() }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("startTourButton")
        }
        .padding(.horizontal, 20).padding(.top, 11).padding(.bottom, 9)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().overlay(Theme.outline.opacity(0.55)) }
    }

    private func prepare(forceRemote: Bool = false) async {
        errorMessage = nil
        do {
            let prepared = try await store.prepare(monumentID: booking.packageID, preferBundled: !forceRemote)
            withAnimation(Motion.change(reduceMotion: reduceMotion)) {
                installed = prepared
                selectedTourLanguage = session.appLanguage
            }
        } catch {
            withAnimation(Motion.change(reduceMotion: reduceMotion)) {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startTour() {
        guard !isStartingTour else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.4)) {
            isStartingTour = true
        }
        Task {
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(900)) }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.45)) {
                started = true
                isStartingTour = false
            }
        }
    }
}

private struct TourLaunchLoadingView: View {
    let booking: TourBooking
    let language: AppLanguage

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.surface, Theme.surfaceContainer, Theme.goldLight.opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("MaraudersLogo")
                    .resizable().scaledToFit()
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Theme.primary.opacity(0.2), radius: 14, y: 8)
                    .accessibilityHidden(true)

                VStack(spacing: 7) {
                    Text("Preparing your guide")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.primary)
                    Text(booking.name)
                        .font(.headline).foregroundStyle(Theme.ink)
                    Text(verbatim: language.title)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.gold)
                }

                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.primary)

                Text("Your tour is about to begin.")
                    .font(.footnote).foregroundStyle(Theme.mutedInk)
            }
            .padding(30)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing your guide for \(booking.name)")
    }
}
