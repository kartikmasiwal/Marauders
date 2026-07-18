import SwiftUI

struct BookingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.surfaceLow.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        ForEach(MockData.monuments) { monument in
                            TourTicketCard(monument: monument)
                        }
                        addTicket
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
                Image(systemName: "ticket.fill")
                    .foregroundStyle(Theme.primary)
                    .padding(12)
                    .background(Theme.surfaceHigh, in: Circle())
                    .overlay(alignment: .topTrailing) {
                        Text("3").font(.caption2.bold()).foregroundStyle(.white).padding(5).background(Theme.primary, in: Circle()).offset(x: 4, y: -4)
                    }
            }
            Text("Three experiences are ready for your next chapter.")
                .foregroundStyle(Theme.mutedInk)
        }
    }

    private var addTicket: some View {
        Button {} label: {
            Label("Add New Ticket", systemImage: "plus.circle")
                .font(.headline)
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(Theme.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [7])) }
        }
    }
}

private struct TourTicketCard: View {
    let monument: Monument

    var body: some View {
        VStack(spacing: 0) {
            Image(monument.imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 165)
                .clipped()
                .overlay(alignment: .topLeading) {
                    Label("OFFLINE READY", systemImage: "checkmark.icloud.fill")
                        .font(.caption2.bold()).tracking(0.8).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Theme.teal.opacity(0.9), in: Capsule())
                        .padding(14)
                }
            VStack(alignment: .leading, spacing: 13) {
                Text(monument.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Label(monument.city, systemImage: "mappin.and.ellipse")
                Label(monument.date, systemImage: "calendar")
                Divider().overlay(Theme.outline.opacity(0.6))
                NavigationLink(value: monument) {
                    HStack {
                        Text("View Ticket").fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityIdentifier("viewTicket_\(monument.id)")
            }
            .font(.subheadline)
            .foregroundStyle(Theme.mutedInk)
            .padding(18)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Theme.outline.opacity(0.7)) }
        .shadow(color: Theme.ink.opacity(0.07), radius: 12, y: 6)
        .navigationDestination(for: Monument.self) { TourContainerView(monument: $0) }
    }
}
