import UIKit

struct BannersWidgetViewModel {
    let showsCloseButton: Bool
    let banners: [BannerViewModel]
    let maxTextHeight: CGFloat
}

struct BannerViewModel {
    let id: String
    let title: String
    let details: String
    let backgroundImage: UIImage?
    let contentImage: UIImage?
    let clipsToBounds: Bool
}
