import Foundation

final class AssetSelectionWireframe: AssetSelectionWireframeProtocol {
    weak var delegate: AssetSelectionDelegate?

    func complete(on view: AssetSelectionViewProtocol, selecting chainAsset: ChainAsset) {
        view.controller.dismiss(animated: true, completion: nil)

        delegate?.assetSelection(view: view, didCompleteWith: chainAsset)
    }
}
