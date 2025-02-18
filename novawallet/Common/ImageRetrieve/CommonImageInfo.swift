import Foundation
import UIKit

struct CommonImageInfo {
    let size: CGSize
    let scale: CGFloat
    let url: URL?

    var cacheKey: String? {
        url?.absoluteString
    }

    var scaledSize: CGSize {
        CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    init(
        size: CGSize,
        scale: CGFloat,
        url: URL? = nil
    ) {
        self.size = size
        self.scale = scale
        self.url = url
    }

    func byChangingURL(_ url: URL) -> Self {
        CommonImageInfo(
            size: size,
            scale: scale,
            url: url
        )
    }
}
