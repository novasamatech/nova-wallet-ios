import Foundation

typealias BannersLocalizedResources = [String: BannerResources]

struct BannerResources: Codable, Equatable {
    let title: String
    let details: String
}
