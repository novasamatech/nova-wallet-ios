import Foundation

final class GovernanceAssetSelectionWireframe {
    weak var delegate: GovernanceAssetSelectionDelegate?

    init(delegate: GovernanceAssetSelectionDelegate) {
        self.delegate = delegate
    }
}

extension GovernanceAssetSelectionWireframe: GovernanceAssetSelectionWireframeProtocol {
    func complete(on view: AssetSelectionViewProtocol, option: GovernanceSelectedOption) {
        view.controller.dismiss(animated: true, completion: nil)

        delegate?.governanceAssetSelection(view: view, didCompleteWith: option)
    }
}
