import UIKit
import Operation_iOS

protocol WebViewRenderImageViewModelFactoryProtocol {
    func createViewModel(for id: UUID) -> WebViewRenderImageViewModel
}

final class WebViewRenderImageViewModelFactory {
    private let fileRepository: FileRepositoryProtocol
    private let renderFetchOperationQueue: OperationQueue

    init(
        fileRepository: FileRepositoryProtocol,
        renderFetchOperationQueue: OperationQueue
    ) {
        self.fileRepository = fileRepository
        self.renderFetchOperationQueue = renderFetchOperationQueue
    }
}

// MARK: WebViewRenderImageViewModelFactoryProtocol

extension WebViewRenderImageViewModelFactory: WebViewRenderImageViewModelFactoryProtocol {
    func createViewModel(for id: UUID) -> WebViewRenderImageViewModel {
        let operationFactory = WebViewRenderFilesOperationFactory(
            repository: fileRepository,
            directoryPath: ApplicationConfig.shared.webPageRenderCachePath
        )

        return WebViewRenderImageViewModel(
            operationFactory: operationFactory,
            id: id,
            fallbackImage: nil,
            renderFetchOperationQueue: renderFetchOperationQueue
        )
    }
}
