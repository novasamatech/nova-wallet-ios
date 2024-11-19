import Foundation

final class ChainAssetSelectionWireframe: ChainAssetSelectionWireframeProtocol {
    weak var delegate: ChainAssetSelectionDelegate?

    func complete(on view: ChainAssetSelectionViewProtocol, selecting chainAsset: ChainAsset) {
        view.controller.dismiss(animated: true, completion: nil)

        delegate?.assetSelection(view: view, didCompleteWith: chainAsset)
    }
}
