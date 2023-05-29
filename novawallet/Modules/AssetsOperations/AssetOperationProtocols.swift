protocol AssetOperationWireframeProtocol: AssetsSearchWireframeProtocol {
    func showSendTokens(from view: AssetsSearchViewProtocol?, chainAsset: ChainAsset)
    func showReceiveTokens(
        from view: AssetsSearchViewProtocol?,
        chainAsset: ChainAsset,
        metaChainAccountResponse: MetaChainAccountResponse
    )
    func showNoLedgerSupport(from view: AssetsSearchViewProtocol?, tokenName: String)
    func showNoKeys(from view: AssetsSearchViewProtocol?)
    func showPurchaseProviders(
        from view: AssetsSearchViewProtocol?,
        actions: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    )
    func showPurchaseTokens(
        from view: AssetsSearchViewProtocol?,
        action: PurchaseAction,
        delegate: PurchaseDelegate
    )
    func presentSuccessAlert(from view: AssetsSearchViewProtocol?, message: String)
}
