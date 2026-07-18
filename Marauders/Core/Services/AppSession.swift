import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    var isAuthenticated = false
    var userPhone = ""

    func signIn(phone: String) {
        userPhone = phone
        isAuthenticated = true
    }

    func signOut() {
        isAuthenticated = false
        userPhone = ""
    }
}
