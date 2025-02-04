import Foundation

struct Banner: Codable, Equatable {
    let id: UUID
    let background: URL
    let image: URL
    let clipsToBounds: Bool
}
