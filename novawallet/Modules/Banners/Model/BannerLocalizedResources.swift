import Foundation

typealias BannersLocalizedResources = [String: BannersLocalizedResource]

struct BannersLocalizedResource {
    let bannerId: String
    let title: String
    let details: String
    let estimatedHeight: Float
}

typealias BannersLocalizedResourcesResponse = [String: BannerLocalizedResourcesResponse]

struct BannerLocalizedResourcesResponse: Codable, Equatable {
    let title: String
    let details: String
}
