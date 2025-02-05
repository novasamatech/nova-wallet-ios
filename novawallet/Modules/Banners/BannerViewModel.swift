import Foundation

struct BannerViewModel {
    let id: String
    let title: String
    let details: String
    let backgroundImage: ImageViewModelProtocol
    let contentImage: ImageViewModelProtocol
    let clipsToBounds: Bool
}
