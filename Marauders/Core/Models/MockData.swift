import Foundation

enum MockData {
    static let monuments: [Monument] = [
        Monument(
            id: "taj-mahal", name: "Taj Mahal", city: "Agra, Uttar Pradesh",
            date: "Today · 10:30 AM", imageName: "TajMahalMap",
            summary: "Walk through the Mughal masterpiece and discover the ideas of symmetry, devotion, and craft behind it.",
            points: [
                TourPoint(id: "taj-gate", number: 1, title: "The Great Gate", subtitle: "Darwaza-i-Rauza", details: "Built in 1648 from red sandstone and white marble, the monumental gateway frames the first dramatic view of the Taj Mahal.", position: .init(x: 0.20, y: 0.68), duration: 96),
                TourPoint(id: "taj-garden", number: 2, title: "Charbagh Gardens", subtitle: "The garden of paradise", details: "Four waterways divide this Persian-inspired garden into balanced quarters, reflecting ideas of paradise and eternity.", position: .init(x: 0.44, y: 0.62), duration: 122),
                TourPoint(id: "taj-pool", number: 3, title: "Marble Pool", subtitle: "The iconic reflection", details: "The long reflecting pool amplifies the mausoleum's symmetry and creates one of the world's most recognized views.", position: .init(x: 0.53, y: 0.47), duration: 88),
                TourPoint(id: "taj-terrace", number: 4, title: "The Marble Terrace", subtitle: "Riverfront platform", details: "The raised terrace unites the mausoleum, mosque, and guest pavilion above the Yamuna riverbank.", position: .init(x: 0.72, y: 0.34), duration: 105)
            ]
        ),
        Monument(
            id: "war-memorial", name: "National War Memorial", city: "New Delhi",
            date: "21 Jul · 4:00 PM", imageName: "WarMemorialMap",
            summary: "Explore the concentric circles of courage, sacrifice, protection, and immortality honoring India's fallen soldiers.",
            points: [
                TourPoint(id: "war-gateway", number: 1, title: "Gateway of Valor", subtitle: "The ceremonial approach", details: "The approach prepares visitors for a journey through stories of duty, courage, and remembrance.", position: .init(x: 0.22, y: 0.73), duration: 76),
                TourPoint(id: "war-tyag", number: 2, title: "Tyag Chakra", subtitle: "Circle of sacrifice", details: "Granite tablets carry the names of soldiers who made the ultimate sacrifice in service of the nation.", position: .init(x: 0.31, y: 0.55), duration: 115),
                TourPoint(id: "war-flame", number: 3, title: "Amar Jawan Jyoti", subtitle: "The eternal flame", details: "The flame symbolizes the immortality of fallen soldiers and the nation's promise never to forget their sacrifice.", position: .init(x: 0.48, y: 0.64), duration: 103),
                TourPoint(id: "war-obelisk", number: 4, title: "Central Obelisk", subtitle: "Heart of the memorial", details: "The soaring stone obelisk anchors the memorial and bears the Ashoka emblem at its crown.", position: .init(x: 0.57, y: 0.48), duration: 91),
                TourPoint(id: "war-veerta", number: 5, title: "Veerta Chakra", subtitle: "Circle of bravery", details: "Bronze murals depict defining acts of bravery by the Indian Armed Forces.", position: .init(x: 0.72, y: 0.40), duration: 128)
            ]
        ),
        Monument(
            id: "zomato-farm", name: "Zomato Farmhouse", city: "Gurugram, Haryana",
            date: "27 Jul · 6:30 PM", imageName: "ZomatoFarmMap",
            summary: "A playful food and culture trail through gardens, restored farm spaces, and contemporary culinary experiences.",
            points: [
                TourPoint(id: "farm-entry", number: 1, title: "The Orchard Gate", subtitle: "Begin the farm trail", details: "Native fruit trees and a shaded stone path create a gentle transition from the city to the farm.", position: .init(x: 0.27, y: 0.72), duration: 72),
                TourPoint(id: "farm-hall", number: 2, title: "The Hall", subtitle: "Culinary and event experience", details: "Originally a granary, The Hall has been restored with terracotta accents and sandstone flooring for chef-led masterclasses.", position: .init(x: 0.49, y: 0.52), duration: 137),
                TourPoint(id: "farm-kitchen", number: 3, title: "Open Kitchen", subtitle: "From farm to table", details: "Watch ingredients travel from nearby beds into a live kitchen centered on seasonal cooking.", position: .init(x: 0.69, y: 0.42), duration: 99),
                TourPoint(id: "farm-lawn", number: 4, title: "Sunset Lawn", subtitle: "Gather under the open sky", details: "The broad lawn hosts music, community tables, and evening celebrations beside the fields.", position: .init(x: 0.63, y: 0.68), duration: 84)
            ]
        )
    ]
}
