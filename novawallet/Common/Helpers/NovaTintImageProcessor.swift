import Kingfisher
import UIKit

final class NovaTintImageProcessor: ImageProcessor {
    let identifier: String
    let tintColor: UIColor

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(kFCrossPlatformImage):
            return kFCrossPlatformImage.tinted(with: tintColor)
        case .data:
            return (DefaultImageProcessor.default |> self).process(item: item, options: options)
        }
    }

    init(tintColor: UIColor) {
        identifier = "io.novafoundation.novawallet.kf.tint(\(tintColor.hexRGBA))"
        self.tintColor = tintColor
    }
}
