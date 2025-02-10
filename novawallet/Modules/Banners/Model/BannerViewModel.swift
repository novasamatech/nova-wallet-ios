import UIKit

struct BannersWidgetviewModel {
    let showsCloseButton: Bool
    let banners: [BannerViewModel]
}

struct BannerViewModel {
    let id: String
    let title: String
    let details: String
    let backgroundImage: UIImage?
    let contentImage: UIImage?
    let clipsToBounds: Bool
}
