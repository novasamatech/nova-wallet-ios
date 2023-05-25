import Foundation

final class AssetsSearchWireframe: AssetsSearchWireframeProtocol {
    private weak var delegate: AssetsSearchDelegate?

    init(delegate: AssetsSearchDelegate) {
        self.delegate = delegate
    }

    func finish(
        selection: ChainAsset,
        view: AssetsSearchViewProtocol?
    ) {
        delegate?.assetSearchDidSelect(chainAssetId: selection.chainAssetId)
        close(view: view)
    }

    func cancel(from view: AssetsSearchViewProtocol?) {
        delegate?.assetSearchDidCancel()
        close(view: view)
    }

    private func close(view: AssetsSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true)
    }
}
