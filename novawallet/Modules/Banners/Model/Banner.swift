import Foundation
import UIKit

struct RemoteBannerModel: Codable, Equatable {
    let id: String
    let background: URL
    let image: URL
    let clipsToBounds: Bool
    let action: String?
}

struct Banner {
    let id: String
    let background: UIImage?
    let image: UIImage?
    let clipsToBounds: Bool
    let actionLink: String?
    let layout: Banners.Layout
}

extension Banners {
    enum Layout {
        case regular
        case featured
    }

    struct LocalBanner {
        let banner: Banner
        let title: String
        let details: String
    }
}
