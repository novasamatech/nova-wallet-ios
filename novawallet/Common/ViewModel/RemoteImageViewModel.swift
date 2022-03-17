import UIKit
import Kingfisher
import SVGKit
import CommonWallet

final class RemoteImageViewModel: NSObject {
    let url: URL

    init(url: URL) {
        self.url = url
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
            options: options
        )
    }

    func cancel(on imageView: UIImageView) {
        imageView.kf.cancelDownloadTask()
    }
}

final class WalletRemoteImageViewModel: WalletImageViewModelProtocol {
    let url: URL
    let size: CGSize

    private var task: DownloadTask?

    init(url: URL, size: CGSize) {
        self.url = url
        self.size = size
    }

    var image: UIImage?

    func loadImage(with completionBlock: @escaping (UIImage?, Error?) -> Void) {
        let processor = SVGImageProcessor()
            |> ResizingImageProcessor(referenceSize: size, mode: .aspectFit)

        let options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheSerializer(RemoteImageSerializer.shared),
            .cacheOriginalImage,
            .diskCacheExpiration(.days(1))
        ]

        task = KingfisherManager.shared.retrieveImage(
            with: url,
            options: options,
            progressBlock: nil,
            downloadTaskUpdated: nil
        ) { result in
            switch result {
            case let .success(imageResult):
                completionBlock(imageResult.image, nil)
            case let .failure(error):
                completionBlock(nil, error)
            }
        }
    }

    func cancel() {
        task?.cancel()
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
            let imsvg = SVGKImage(data: data)
            return imsvg?.uiImage ?? UIImage()
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
