import Foundation

enum ExpirationTimeViewModel {
    case normal(time: String)
    case expiring(time: String)
    case expired
}
