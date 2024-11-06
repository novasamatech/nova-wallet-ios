import Foundation

protocol GovernanceChainSelectionDelegate: AnyObject {
    func governanceAssetSelection(
        view: ChainAssetSelectionViewProtocol,
        didCompleteWith option: GovernanceSelectedOption
    )
}

protocol GovernanceChainSelectionWireframeProtocol: ChainAssetSelectionBaseWireframeProtocol {
    func complete(on view: ChainAssetSelectionViewProtocol, option: GovernanceSelectedOption)
}
