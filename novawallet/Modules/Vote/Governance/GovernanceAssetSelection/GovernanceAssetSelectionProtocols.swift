import Foundation

protocol GovernanceAssetSelectionDelegate: AnyObject {
    func governanceAssetSelection(
        view: AssetSelectionViewProtocol,
        didCompleteWith option: GovernanceSelectedOption
    )
}

protocol GovernanceAssetSelectionWireframeProtocol: AssetSelectionBaseWireframeProtocol {
    func complete(on view: AssetSelectionViewProtocol, option: GovernanceSelectedOption)
}
