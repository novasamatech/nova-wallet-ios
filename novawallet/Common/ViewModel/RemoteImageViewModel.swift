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
    func loadImage(on imageView: UIImageView, targetSize: CGSize, cornerRadius: CGFloat, animated: Bool) {
        let processor = SVGImageProcessor(targetSize: targetSize)
            |> DownsamplingImageProcessor(size: targetSize)
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
        let processor = SVGImageProcessor(targetSize: size)
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

    func data(with image: KFCrossPlatformImage, original: Data?) -> Data? {
        DefaultCacheSerializer.default.data(with: image, original: original)
    }

    func image(with data: Data, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        if let uiImage = DefaultCacheSerializer.default.image(with: data, options: options) {
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

    init(targetSize: CGSize) {
        identifier = "io.novafoundation.novawallet.kf.svg.processor(\(targetSize)"
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
