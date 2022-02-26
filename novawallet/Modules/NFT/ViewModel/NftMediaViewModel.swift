import UIKit
import RobinHood
import Kingfisher

struct NftMediaDisplaySettings {
    let targetSize: CGSize
    let cornerRadius: CGFloat
    let animated: Bool
}

protocol NftMediaViewModelProtocol {
    func loadMedia(on imageView: UIImageView, displaySettings: NftMediaDisplaySettings, completion: ((Error?) -> Void)?)
    func cancel(on imageView: UIImageView)
}

final class NftMediaViewModel {
    let metadataReference: String
    let downloadService: NftFileDownloadServiceProtocol

    private var loadingOperation: CancellableCall?
    private var remoteImageViewModel: NftImageViewModel?

    init(metadataReference: String, downloadService: NftFileDownloadServiceProtocol) {
        self.metadataReference = metadataReference
        self.downloadService = downloadService
    }

    private func handle(
        result: Result<URL, Error>,
        on imageView: UIImageView,
        displaySettings: NftMediaDisplaySettings,
        completion: ((Error?) -> Void)?
    ) {
        switch result {
        case let .success(url):
            remoteImageViewModel = NftImageViewModel(url: url)
            remoteImageViewModel?.loadMedia(on: imageView, displaySettings: displaySettings, completion: completion)
        case let .failure(error):
            completion?(error)
        }
    }
}

extension NftMediaViewModel: NftMediaViewModelProtocol {
    func loadMedia(
        on imageView: UIImageView,
        displaySettings: NftMediaDisplaySettings,
        completion: ((Error?) -> Void)?
    ) {
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
                displaySettings: displaySettings,
                completion: completion
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
