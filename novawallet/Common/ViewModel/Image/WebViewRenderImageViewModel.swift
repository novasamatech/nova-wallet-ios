import UIKit
import Kingfisher
import SwiftDraw
import Operation_iOS

final class WebViewRenderImageViewModel: NSObject {
    let id: UUID
    let fallbackImage: UIImage?

    private let operationFactory: WebViewRenderFilesOperationFactoryProtocol
    private let renderFetchOperationQueue: OperationQueue
    
    private imageOperationCallStore = CancellableCallStore()

    init(
        operationFactory: WebViewRenderFilesOperationFactoryProtocol,
        id: UUID,
        fallbackImage: UIImage? = nil,
        renderFetchOperationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory
        self.id = id
        self.fallbackImage = fallbackImage
        self.renderFetchOperationQueue = renderFetchOperationQueue
    }
}

// MARK: ImageViewModelProtocol

extension WebViewRenderImageViewModel: ImageViewModelProtocol {
    func loadImage(
        on imageView: UIImageView,
        settings _: ImageViewModelSettings,
        animated _: Bool
    ) {
        let renderFetchWrapper = operationFactory.fetchRender(for: id)

        executeCancellable(
            wrapper: renderFetchWrapper,
            inOperationQueue: renderFetchOperationQueue,
            backingCallIn: imageOperationCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in

            switch result {
            case let .success(renderData):
                guard let renderData else {
                    imageView.image = self?.fallbackImage

                    return
                }

                let image = UIImage(data: renderData)
                imageView.image = image
            case .failure:
                imageView.image = self?.fallbackImage
            }
        }
    }

    func cancel(on imageView: UIImageView) {
        imageOperationCallStore.cancel()
    }
}
