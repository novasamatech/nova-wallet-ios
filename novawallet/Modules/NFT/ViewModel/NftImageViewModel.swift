import UIKit
import Kingfisher

final class NftImageViewModel: NftMediaViewModelProtocol {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func loadMedia(
        on imageView: UIImageView,
        displaySettings: NftMediaDisplaySettings,
        completion: ((Error?) -> Void)?
    ) {
        let targetSize = displaySettings.targetSize
        let cornerRadius = displaySettings.cornerRadius
        let animated = displaySettings.animated

        let processor = SVGImageProcessor(targetSize: targetSize)
            |> DownsamplingImageProcessor(size: targetSize)
            |> RoundCornerImageProcessor(cornerRadius: cornerRadius)

        var options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheSerializer(RemoteImageSerializer(targetSize: targetSize)),
            .cacheOriginalImage,
            .diskCacheExpiration(.days(1))
        ]

        if animated {
            options.append(.transition(.fade(0.25)))
        }

        imageView.kf.setImage(
            with: url,
            options: options, completionHandler: { result in
                switch result {
                case .success:
                    completion?(nil)
                case let .failure(error):
                    if !error.isTaskCancelled {
                        completion?(error)
                    }
                }
            }
        )
    }

    func cancel(on imageView: UIImageView) {
        imageView.kf.cancelDownloadTask()
    }
}
