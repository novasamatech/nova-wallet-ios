import Foundation
import RobinHood
import SubstrateSdk

final class NftListRMRKV2ViewModel {
    let metadataReference: String
    let metadataService: NftFileDownloadServiceProtocol
    let fallbackName: String?
    let imageUrl: String?
    let label: String

    private var loadingOperation: CancellableCall?

    init(
        metadataReference: String,
        metadataService: NftFileDownloadServiceProtocol,
        label: String,
        imageUrl: String?,
        fallbackName: String?
    ) {
        self.metadataReference = metadataReference
        self.metadataService = metadataService
        self.label = label
        self.imageUrl = imageUrl
        self.fallbackName = fallbackName
    }

    func provideData(from json: JSON, to view: NftListItemViewProtocol) {
        let name = json.name?.stringValue ?? fallbackName
        view.setName(name)
    }

    private func handle(
        result: Result<JSON, Error>,
        on view: NftListItemViewProtocol,
        completion: ((Error?) -> Void)?
    ) {
        switch result {
        case let .success(json):
            provideData(from: json, to: view)
            completion?(nil)
        case let .failure(error):
            completion?(error)
        }
    }
}

extension NftListRMRKV2ViewModel: NftListMetadataViewModelProtocol {
    func load(on view: NftListItemViewProtocol, completion: ((Error?) -> Void)?) {
        guard loadingOperation == nil else {
            return
        }

        view.setLabel(label)

        if let urlString = imageUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            let mediaViewModel = NftImageViewModel(url: url)

            view.setMedia(mediaViewModel)
        } else {
            let mediaViewModel = NftMediaViewModel(
                metadataReference: metadataReference,
                aliases: NftMediaAlias.list,
                downloadService: metadataService
            )

            view.setMedia(mediaViewModel)
        }

        loadingOperation = metadataService.downloadMetadata(
            for: metadataReference,
            dispatchQueue: .main
        ) { [weak self, weak view] result in
            guard self?.loadingOperation != nil else {
                return
            }

            self?.loadingOperation = nil

            guard let strongView = view else {
                return
            }

            self?.handle(result: result, on: strongView, completion: completion)
        }
    }

    func cancel(on _: NftListItemViewProtocol) {
        let operationToCancel = loadingOperation
        loadingOperation = nil
        operationToCancel?.cancel()
    }
}
