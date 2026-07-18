import Testing
@testable import Marauders

struct MaraudersTests {
    @Test func includesThreeDemoMonuments() {
        #expect(MockData.monuments.count == 3)
        #expect(MockData.monuments.allSatisfy { !$0.points.isEmpty })
    }

    @Test func acceptsOnlyDemoOTP() async throws {
        let service = DemoAuthenticationService()
        #expect(try await service.verify(otp: "123456"))
        #expect(try await !service.verify(otp: "000000"))
    }

    @Test func hotspotCoordinatesAreNormalized() {
        let points = MockData.monuments.flatMap(\.points)
        #expect(points.allSatisfy { (0...1).contains($0.position.x) && (0...1).contains($0.position.y) })
    }
}
