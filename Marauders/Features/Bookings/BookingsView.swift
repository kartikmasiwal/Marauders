import SwiftUI

struct BookingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.surfaceLow.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
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
    @StateObject private var store = PackageStore()
    @State private var installed: InstalledTour?
    @State private var selectedLanguage = "en"
    @State private var errorMessage: String?
    @State private var started = false

    var body: some View {
        Group {
            if started, let installed {
                TourContainerView(booking: booking, installed: installed, language: selectedLanguage)
            } else {
                preparation
            }
        }
        .navigationTitle(started ? "" : booking.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(started ? .hidden : .visible, for: .tabBar)
        .task { await prepare() }
    }

    private var preparation: some View {
        ZStack {
            Theme.surfaceLow.ignoresSafeArea()
            VStack(spacing: 22) {
                Image(booking.imageName).resizable().scaledToFill().frame(height: 250).clipped().clipShape(RoundedRectangle(cornerRadius: 26))
                    .allowsHitTesting(false).accessibilityHidden(true)
                if let installed {
                    Image(systemName: "checkmark.icloud.fill").font(.system(size: 42)).foregroundStyle(Theme.teal)
                    Text("Tour ready offline").font(.title2.bold())
                    Text(installed.package.monument.overview.v(selectedLanguage)).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
                    languagePicker(for: installed.package.monument.languages)
                    Button("Start Tour") { started = true }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("startTourButton")
                } else if let errorMessage {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 40)).foregroundStyle(Theme.primary)
                    Text(errorMessage).foregroundStyle(Theme.mutedInk).multilineTextAlignment(.center)
                    Button("Retry Download") { Task { await prepare(forceRemote: true) } }.buttonStyle(PrimaryButtonStyle())
                } else {
                    ProgressView(value: store.downloadProgress)
                    Text(store.isDownloading ? "Preparing offline package…" : "Checking tour package…").foregroundStyle(Theme.mutedInk)
                }
                Spacer()
            }.padding(20)
        }
    }

    private func prepare(forceRemote: Bool = false) async {
        errorMessage = nil
        do {
            installed = try await store.prepare(monumentID: booking.packageID, preferBundled: !forceRemote)
            selectedLanguage = installed?.package.monument.languages.first ?? "en"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func languagePicker(for languages: [String]) -> some View {
        if languages.count > 3 {
            Picker("Guide language", selection: $selectedLanguage) {
                languageOptions(languages)
            }
            .pickerStyle(.menu)
            .tint(Theme.primary)
            .accessibilityIdentifier("languagePicker")
        } else {
            Picker("Guide language", selection: $selectedLanguage) {
                languageOptions(languages)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("languagePicker")
        }
    }

    @ViewBuilder
    private func languageOptions(_ languages: [String]) -> some View {
        ForEach(languages, id: \.self) { code in
            Text(languageLabel(for: code)).tag(code)
        }
    }

    private func languageLabel(for code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized(with: locale) ?? code.uppercased()
    }
}
