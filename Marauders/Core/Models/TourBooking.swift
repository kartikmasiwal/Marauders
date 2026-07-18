import Foundation

struct TourBooking: Identifiable, Hashable {
    let id: String
    let packageID: String
    let name: String
    let city: String
    let date: String
    let imageName: String
    let packageAvailable: Bool
}
