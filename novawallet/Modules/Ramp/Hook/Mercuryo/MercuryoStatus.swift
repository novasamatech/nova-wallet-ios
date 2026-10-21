import Foundation

enum MercuryoStatus: String, Decodable {
    case new
    case pending
    case succeeded
    case completed
    case paid
    case failed
}
