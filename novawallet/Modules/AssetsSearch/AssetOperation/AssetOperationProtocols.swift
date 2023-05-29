typealias AssetOperationViewProtocol = AssetsSearchViewProtocol

protocol AssetOperationWireframeProtocol: AssetsSearchWireframeProtocol {
    func showSendTokens(from view: AssetOperationViewProtocol?, chainAsset: ChainAsset)
    func showReceiveTokens(
        from view: AssetOperationViewProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    )
    func showNoLedgerSupport(from view: AssetOperationViewProtocol?, tokenName: String)
    func showNoKeys(from view: AssetOperationViewProtocol?)
    func showPurchaseProviders(
        from view: AssetOperationViewProtocol?,
        actions: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    )
    func showPurchaseTokens(
        from view: AssetOperationViewProtocol?,
        action: PurchaseAction,
        delegate: PurchaseDelegate
    )
    func presentSuccessAlert(from view: AssetOperationViewProtocol?, message: String)
}
