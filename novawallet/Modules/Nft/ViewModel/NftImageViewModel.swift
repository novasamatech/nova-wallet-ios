import UIKit
import Kingfisher

final class NftImageViewModel: NftMediaViewModelProtocol {
    let url: URL

    var identifier: String { url.absoluteString }

    init(url: URL) {
        self.url = url
    }

    func loadMedia(
        on imageView: UIImageView,
        displaySettings: NftMediaDisplaySettings,
        completion: ((Bool, Error?) -> Void)?
    ) {
        let targetSize = displaySettings.targetSize
        let cornerRadius = displaySettings.cornerRadius
        let animated = displaySettings.animated

        let scaleProcessor: ImageProcessor

        if displaySettings.isAspectFit {
            scaleProcessor = ResizingImageProcessor(referenceSize: targetSize, mode: .aspectFit)
        } else {
            scaleProcessor = DownsamplingImageProcessor(size: targetSize)
        }

        let processor = SVGImageProcessor()
            |> scaleProcessor
            |> RoundCornerImageProcessor(cornerRadius: cornerRadius)

        var options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheSerializer(RemoteImageSerializer.shared),
            .cacheOriginalImage,
            .diskCacheExpiration(.days(1))
        ]

        if animated {
            options.append(.transition(.fade(0.25)))
        }

        imageView.kf.setImage(
            with: url,
            options: options,
            completionHandler: { result in
                switch result {
                case .success:
                    completion?(true, nil)
                case let .failure(error):
                    if !error.isTaskCancelled {
                        completion?(true, error)
                    }
                }
            }
        )
    }

    func cancel(on imageView: UIImageView) {
        imageView.kf.cancelDownloadTask()
    }
}
