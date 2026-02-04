import Foundation

struct ASMRemoteData: Codable, Equatable {
    let bannerPath: Banners.Domain
    let wikiURL: URL
    let destinationLinkData: AppLinkData
    let sourceLinkData: AppLinkData
}

extension ASMRemoteData {
    struct AppLinkData: Codable, Equatable {
        let universalLink: URL
        let urlScheme: String
    }
}

extension ASMRemoteData {
    var cacheKey: String {
        destinationLinkData.universalLink.absoluteString
    }
}
