import Foundation

final class GovernanceChainSelectionWireframe {
    weak var delegate: GovernanceChainSelectionDelegate?

    init(delegate: GovernanceChainSelectionDelegate) {
        self.delegate = delegate
    }
}

extension GovernanceChainSelectionWireframe: GovernanceChainSelectionWireframeProtocol {
    func complete(on view: ChainAssetSelectionViewProtocol, option: GovernanceSelectedOption) {
        view.controller.dismiss(animated: true, completion: nil)

        delegate?.governanceAssetSelection(view: view, didCompleteWith: option)
    }
}
