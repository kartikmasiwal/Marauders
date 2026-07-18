import Foundation

enum MockData {
    static let bookings: [TourBooking] = [
        TourBooking(
            id: "booking-taj", packageID: "taj_mahal", name: "Taj Mahal",
            city: "Agra, Uttar Pradesh", date: "Today · 10:30 AM",
            imageName: "TajMahalMap", packageAvailable: true
        ),
        TourBooking(
            id: "booking-war", packageID: "national_war_memorial", name: "National War Memorial",
            city: "New Delhi", date: "21 Jul · 4:00 PM",
            imageName: "WarMemorialMap", packageAvailable: false
        ),
        TourBooking(
            id: "booking-farm", packageID: "zomato_farmhouse", name: "Zomato Farmhouse",
            city: "Gurugram, Haryana", date: "27 Jul · 6:30 PM",
            imageName: "ZomatoFarmMap", packageAvailable: false
        )
    ]
}
