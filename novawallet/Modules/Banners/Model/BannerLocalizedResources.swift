import Foundation

typealias BannersLocalizedResources = [UUID: BannerResources]

struct BannerResources: Codable, Equatable {
    let title: String
    let details: String
}
