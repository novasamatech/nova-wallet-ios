import UIKit
import RobinHood
import Kingfisher

protocol NFTMediaViewModelProtocol {
    func loadMedia(on imageView: UIImageView, targetSize: CGSize, cornerRadius: CGFloat, animated: Bool)
    func cancel(on imageView: UIImageView)
}

final class NFTImageViewModel {
    let metadataReference: String
    let downloadService: NftFileDownloadServiceProtocol

    private var loadingOperation: CancellableCall?
    private var remoteImageViewModel: RemoteImageViewModel?

    init(metadataReference: String, downloadService: NftFileDownloadServiceProtocol) {
        self.metadataReference = metadataReference
        self.downloadService = downloadService
    }

    private func handle(result: Result<URL, Error>, on imageView: UIImageView, targetSize: CGSize, cornerRadius: CGFloat, animated: Bool) {
        switch result {
        case let .success(url):
            remoteImageViewModel = RemoteImageViewModel(url: url)
            remoteImageViewModel?.loadImage(on: imageView, targetSize: targetSize, cornerRadius: cornerRadius, animated: animated)
        case .failure:
            break
        }
    }
}

extension NFTImageViewModel: NFTMediaViewModelProtocol {
    func loadMedia(on imageView: UIImageView, targetSize: CGSize, cornerRadius: CGFloat, animated: Bool) {
        guard loadingOperation == nil else {
            return
        }

        _ = loadingOperation = downloadService.resolveImageUrl(
            for: metadataReference,
            dispatchQueue: .main
        ) { [weak self, weak imageView] result in
            guard self?.loadingOperation != nil else {
                return
            }

            self?.loadingOperation = nil

            guard let strongImageView = imageView else {
                return
            }

            self?.handle(
                result: result,
                on: strongImageView,
                targetSize: targetSize,
                cornerRadius: cornerRadius,
                animated: animated
            )
        }
    }

    func cancel(on imageView: UIImageView) {
        let operationToCancel = loadingOperation
        loadingOperation = nil
        operationToCancel?.cancel()

        remoteImageViewModel?.cancel(on: imageView)
        remoteImageViewModel = nil
    }
}

extension RemoteImageViewModel: NFTMediaViewModelProtocol {
    func loadMedia(on imageView: UIImageView, targetSize: CGSize, cornerRadius: CGFloat, animated: Bool) {
        loadImage(on: imageView, targetSize: targetSize, cornerRadius: cornerRadius, animated: animated)
    }
}
