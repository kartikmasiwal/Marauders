import Foundation
import CoreGraphics

struct Monument: Identifiable, Hashable {
    let id: String
    let name: String
    let city: String
    let date: String
    let imageName: String
    let summary: String
    let points: [TourPoint]
}

struct TourPoint: Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let subtitle: String
    let details: String
    let position: CGPoint
    let duration: TimeInterval

    static func == (lhs: TourPoint, rhs: TourPoint) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
