import SwiftUI

struct ExploreView: View {
    var body: some View {
        NavigationStack {
            List(MockData.monuments) { monument in
                NavigationLink(value: monument) {
                    HStack(spacing: 14) {
                        Image(monument.imageName).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(monument.name).font(.headline)
                            Text(monument.city).font(.subheadline).foregroundStyle(Theme.mutedInk)
                            Text("\(monument.points.count) chapters").font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.surfaceLow)
            .navigationTitle("Explore")
            .navigationDestination(for: Monument.self) { TourContainerView(monument: $0) }
        }
    }
}
