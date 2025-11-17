import UIKit
import Kingfisher
import SwiftDraw
import Operation_iOS

final class RemoteImageViewModel: NSObject {
    let url: URL
    let fallbackImage: UIImage?

    init(
        url: URL,
        fallbackImage: UIImage? = nil
    ) {
        self.url = url
        self.fallbackImage = fallbackImage
    }
}

extension RemoteImageViewModel: ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, settings: ImageViewModelSettings, animated: Bool) {
        var processor: ImageProcessor = SVGImageProcessor() |>
            ResizingImageProcessor(referenceSize: settings.targetSize, mode: .aspectFill) |>
            CroppingImageProcessor(size: settings.targetSize)

        if let tintColor = settings.tintColor {
            processor = processor |> NovaTintImageProcessor(tintColor: tintColor)
        }

        if let cornerRadius = settings.cornerRadius, cornerRadius > 0 {
            processor = processor |> RoundCornerImageProcessor(cornerRadius: cornerRadius)
        }

        var options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale)
        ] + KingfisherOptionsInfo.cacheOptions

        if let renderingMode = settings.renderingMode {
            let imageModifier = RenderingModeImageModifier(renderingMode: renderingMode)
            options.append(.imageModifier(imageModifier))
        }

        if animated {
            options.append(.transition(.fade(0.25)))
        }

        imageView.kf.setImage(
            with: url,
            options: options
        ) { [weak self] result in
            guard let self else {
                return
            }

            guard case let .failure(error) = result else {
                return
            }

            // set fallback image only if loading wasn't interrupted
            if !error.isTaskCancelled, !error.isNotCurrentTask, let fallbackImage {
                imageView.image = fallbackImage
            }
        }
    }

    func cancel(on imageView: UIImageView) {
        imageView.kf.cancelDownloadTask() // cancel any dowload task

        let url: URL? = nil
        imageView.kf.setImage(with: url) // cancel any cache retrieval task
    }
}

extension RemoteImageViewModel: Identifiable {
    var identifier: String {
        url.absoluteString
    }
}

final class RemoteImageSerializer: CacheSerializer {
    static let shared = RemoteImageSerializer()

    private lazy var internalCache = FormatIndicatedCacheSerializer.png

    func data(with image: KFCrossPlatformImage, original: Data?) -> Data? {
        internalCache.data(with: image, original: original)
    }

    func image(with data: Data, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        if let uiImage = internalCache.image(with: data, options: options) {
            return uiImage
        } else {
            return UIImage(svgData: data)
        }
    }
}

final class SVGImageProcessor: ImageProcessor {
    let identifier: String

    let serializer: RemoteImageSerializer

    init() {
        identifier = "io.novafoundation.novawallet.kf.svg.processor"
        serializer = RemoteImageSerializer.shared
    }

    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            return image
        case let .data(data):
            return serializer.image(with: data, options: options)
        }
    }
}
