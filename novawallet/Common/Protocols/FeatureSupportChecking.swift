import Foundation

protocol FeatureSupportChecking {
    func checkingSupport(
        of feature: SupportCheckingFeatureType,
        for metaAccountModel: MetaAccountModel,
        sheetPresentingView: ControllerBackedProtocol?,
        successClosure: @escaping () -> Void
    )
}

// MARK: - Multisig check

private extension FeatureSupportChecking where Self: MessageSheetPresentable {
    func checkMultisigSellSupport(
        for multisigMetaAccount: MetaAccountModel,
        sheetPresentingView: ControllerBackedProtocol,
        successClosure: @escaping () -> Void
    ) {
        let unsupportedClosure: () -> Void = { [weak self] in
            self?.presentFeatureUnsupportedView(
                from: sheetPresentingView,
                type: .sell,
                walletType: .init(walletType: multisigMetaAccount.type),
                completion: {}
            )
        }

        checkIfMultisigThreshold1(
            multisigMetaAccount: multisigMetaAccount,
            successClosure: successClosure,
            unsupportedClosure: unsupportedClosure
        )
    }

    func checkMultisigCardSupport(
        for multisigMetaAccount: MetaAccountModel,
        sheetPresentingView: ControllerBackedProtocol,
        successClosure: @escaping () -> Void
    ) {
        let unsupportedClosure: () -> Void = { [weak self] in
            self?.presentFeatureUnsupportedView(
                from: sheetPresentingView,
                type: .card,
                walletType: .init(walletType: multisigMetaAccount.type),
                completion: {}
            )
        }

        checkIfMultisigThreshold1(
            multisigMetaAccount: multisigMetaAccount,
            successClosure: successClosure,
            unsupportedClosure: unsupportedClosure
        )
    }

    func checkIfMultisigThreshold1(
        multisigMetaAccount: MetaAccountModel,
        successClosure: @escaping () -> Void,
        unsupportedClosure: @escaping () -> Void
    ) {
        guard
            let multisigContext = multisigMetaAccount.multisigAccount?.multisig,
            multisigContext.threshold == 1
        else {
            unsupportedClosure()
            return
        }

        successClosure()
    }
}

extension FeatureSupportChecking where Self: MessageSheetPresentable {
    func checkingSupport(
        of feature: SupportCheckingFeatureType,
        for metaAccountModel: MetaAccountModel,
        sheetPresentingView: ControllerBackedProtocol?,
        successClosure: @escaping () -> Void
    ) {
        guard let sheetPresentingView else { return }

        switch (feature, metaAccountModel.type) {
        case (.sell, .multisig):
            checkMultisigSellSupport(
                for: metaAccountModel,
                sheetPresentingView: sheetPresentingView,
                successClosure: successClosure
            )
        case (.card, .multisig):
            checkMultisigCardSupport(
                for: metaAccountModel,
                sheetPresentingView: sheetPresentingView,
                successClosure: successClosure
            )
        default:
            successClosure()
        }
    }
}
