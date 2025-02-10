import Foundation

struct BannersFetchResult {
    let banners: [Banner]
    let closedBannerIds: Set<String>?
    let localizedResources: BannersLocalizedResources
}
