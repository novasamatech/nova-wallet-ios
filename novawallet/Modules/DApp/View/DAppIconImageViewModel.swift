import UIKit

enum DAppIconImageViewModel {
    case favicon(ImageViewModelProtocol)
    case icon(ImageViewModelProtocol)

    private var imageViewModel: ImageViewModelProtocol {
        switch self {
        case let .favicon(viewModel),
             let .icon(viewModel):
            return viewModel
        }
    }
}

// MARK: ImageViewModelProtocol

extension DAppIconImageViewModel: ImageViewModelProtocol {
    var proposedTargetSize: CGSize? {
        switch self {
        case .favicon:
            return CGSize(width: 36, height: 36)
        case .icon:
            return CGSize(width: 48, height: 48)
        }
    }

    func loadImage(
        on imageView: UIImageView,
        settings: ImageViewModelSettings,
        animated: Bool
    ) {
        imageViewModel.loadImage(
            on: imageView,
            settings: settings,
            animated: animated
        )
    }

    func cancel(on imageView: UIImageView) {
        imageViewModel.cancel(on: imageView)
    }
}
