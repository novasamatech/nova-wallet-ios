import Foundation

struct Banner: Codable, Equatable {
    let id: String
    let background: URL
    let image: URL
    let clipsToBounds: Bool
}
