import Foundation

struct ClosedBanners: Codable {
    private var bannerIds: Set<String> = []

    func contains(_ id: String) -> Bool {
        bannerIds.contains(id)
    }

    mutating func add(_ id: String) {
        bannerIds.insert(id)
    }

    mutating func remove(_ id: String) {
        bannerIds.remove(id)
    }
}
