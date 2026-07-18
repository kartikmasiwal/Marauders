import SwiftUI

struct ExploreView: View {
    var body: some View {
        NavigationStack {
            List(MockData.bookings) { booking in
                NavigationLink(value: booking) {
                    HStack(spacing: 14) {
                        Image(booking.imageName).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 14))
                            .allowsHitTesting(false).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(booking.name).font(.headline)
                            Text(booking.city).font(.subheadline).foregroundStyle(Theme.mutedInk)
                            Text(booking.packageAvailable ? "Offline demo ready" : "Backend package").font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                        }
                    }.padding(.vertical, 5)
                }
            }
            .scrollContentBackground(.hidden).background(Theme.surfaceLow).navigationTitle("Explore")
            .navigationDestination(for: TourBooking.self) { TourPreparationView(booking: $0) }
        }
    }
}
