import Foundation
import Kingfisher

final class WidthScaleFitProcessor: ImageProcessor {
    let identifier: String

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(kFCrossPlatformImage):
            let height = (preferredWidth / kFCrossPlatformImage.size.width)
                * kFCrossPlatformImage.size.height

            let scaleProcessor: ImageProcessor

            if let maxHeight = maxHeight, maxHeight < height {
                let width = (maxHeight / kFCrossPlatformImage.size.height) * kFCrossPlatformImage.size.width
                scaleProcessor = ResizingImageProcessor(referenceSize: CGSize(width: width, height: maxHeight))
            } else {
                scaleProcessor = ResizingImageProcessor(referenceSize: CGSize(width: preferredWidth, height: height))
            }

            return scaleProcessor.process(item: item, options: options)
        case .data:
            return (DefaultImageProcessor.default |> self).process(item: item, options: options)
        }
    }

    let preferredWidth: CGFloat
    let maxHeight: CGFloat?

    init(preferredWidth: CGFloat, maxHeight: CGFloat? = nil) {
        self.preferredWidth = preferredWidth
        self.maxHeight = maxHeight

        let baseIdentifier = "io.novafoundation.novawallet.kf.width.resize.processor"

        if let maxHeight = maxHeight {
            identifier = baseIdentifier + "(\(preferredWidth), \(maxHeight))"
        } else {
            identifier = baseIdentifier + "(\(preferredWidth))"
        }
    }
}
