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
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool) {
        let processor = SVGProcessor(targetSize: targetSize)
            |> DownsamplingImageProcessor(size: targetSize)
            |> RoundCornerImageProcessor(cornerRadius: targetSize.height / 2.0)

        var options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheSerializer(RemoteSerializer(targetSize: targetSize)),
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
        let processor = SVGProcessor(targetSize: size)
            |> ResizingImageProcessor(referenceSize: size, mode: .aspectFit)

        let options: KingfisherOptionsInfo = [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .cacheSerializer(RemoteSerializer(targetSize: size)),
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

private final class RemoteSerializer: CacheSerializer {
    let targetSize: CGSize

    init(targetSize: CGSize) {
        self.targetSize = targetSize
    }

    func data(with _: KFCrossPlatformImage, original: Data?) -> Data? {
        original
    }

    func image(with data: Data, options _: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        if let uiImage = UIImage(data: data) {
            return uiImage
        } else {
            let imsvg = SVGKImage(data: data)
            imsvg?.scaleToFit(inside: targetSize)
            return imsvg?.uiImage ?? UIImage()
        }
    }
}

private final class SVGProcessor: ImageProcessor {
    let identifier: String = "jp.co.soramitsu.fearless.kf.svg.processor"

    let serializer: RemoteSerializer

    init(targetSize: CGSize) {
        serializer = RemoteSerializer(targetSize: targetSize)
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
