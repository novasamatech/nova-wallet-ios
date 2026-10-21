extension MessageSheetPresentable {
    func presentOperationCompletion(
        on view: ControllerBackedProtocol?,
        by checkResult: OperationCheckCommonResult,
        successRouteClosure: () -> Void
    ) {
        guard let view = view else {
            return
        }
        switch checkResult {
        case .available:
            successRouteClosure()
        case .ledgerNotSupported:
            presentSignerNotSupportedView(
                from: view,
                type: .ledger,
                completion: {}
            )
        case let .noSellSupport(wallet, _):
            presentFeatureUnsupportedView(
                from: view,
                type: .sell,
                walletType: .init(walletType: wallet.type),
                completion: {}
            )
        case let .noGiftSupport(wallet):
            presentFeatureUnsupportedView(
                from: view,
                type: .gift,
                walletType: .init(walletType: wallet.type),
                completion: {}
            )
        case let .noSubtensorStakingSupport(walletType):
            presentFeatureUnsupportedView(
                from: view,
                type: .subtensorStaking,
                walletType: .init(walletType: walletType),
                completion: {}
            )
        case .noRampActions:
            break
        case .noSigning:
            presentNoSigningView(from: view, completion: {})
        }
    }
}
