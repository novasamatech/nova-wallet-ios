import Foundation

struct BannerViewModel {
    let id: UUID
    let title: String
    let details: String
    let backgroundImage: ImageViewModelProtocol
    let contentImage: ImageViewModelProtocol
    let clipsToBounds: Bool
}
