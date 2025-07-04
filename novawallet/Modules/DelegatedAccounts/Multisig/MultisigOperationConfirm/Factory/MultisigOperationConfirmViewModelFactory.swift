import Foundation
import SubstrateSdk

protocol MultisigOperationConfirmViewModelFactoryProtocol {
    func createViewModel(
        params: MultisigOperationConfirmViewModelParams,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel

    func createFeeFieldViewModel(
        fee: ExtrinsicFeeProtocol?,
        feeAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>
}

final class MultisigOperationConfirmViewModelFactory {
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol
    let iconViewModelFactory: IconViewModelFactoryProtocol

    init(
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconViewModelFactory: IconViewModelFactoryProtocol = IconViewModelFactory()
    ) {
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.utilityBalanceViewModelFactory = utilityBalanceViewModelFactory
        self.iconViewModelFactory = iconViewModelFactory
    }
}

// MARK: - Private

private extension MultisigOperationConfirmViewModelFactory {
    func createWalletViewModel(using wallet: MetaAccountModel) -> StackCellViewModel {
        createWalletViewModel(
            using: wallet.walletIdenticonData(),
            name: wallet.name
        )
    }

    func createWalletViewModel(
        using identiconData: Data?,
        name: String
    ) -> StackCellViewModel {
        StackCellViewModel(
            details: name,
            imageViewModel: iconViewModelFactory.createDrawableIconViewModel(from: identiconData)
        )
    }

    func createOriginSection(
        chain: ChainModel,
        wallet: MetaAccountModel,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel.Section? {
        let networkModel = networkViewModelFactory.createViewModel(from: chain)
        let walletViewModel = createWalletViewModel(using: wallet)

        let networkField = MultisigOperationConfirmViewModel.SectionField(
            title: R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages),
            value: networkModel
        )
        let walletField = MultisigOperationConfirmViewModel.SectionField(
            title: R.string.localizable.commonMultisig(preferredLanguages: locale.rLanguages),
            value: walletViewModel
        )

        let originViewModel = MultisigOperationConfirmViewModel.OriginModel(
            network: networkField,
            wallet: walletField,
            onBehalfOf: nil
        )

        return .origin(originViewModel)
    }

    func createSignatorySection(
        for pendingOperation: Multisig.PendingOperation,
        multisigWallet: MetaAccountModel,
        signatories: [Multisig.Signatory],
        fee: ExtrinsicFeeProtocol?,
        feeAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel.Section? {
        guard
            let multisigContext = multisigWallet.multisigAccount?.multisig,
            let definition = pendingOperation.multisigDefinition,
            let signatory = signatories.first(
                where: { $0.localAccount?.chainAccount.accountId == multisigContext.signatory }
            ),
            case let .local(localSignatory) = signatory
        else { return nil }

        let approved = definition.approvals.count >= multisigContext.threshold

        guard !approved else { return nil }

        let walletViewModel = createWalletViewModel(
            using: localSignatory.metaAccount.walletIdenticonData,
            name: localSignatory.metaAccount.chainAccount.name
        )
        let signatoryField = MultisigOperationConfirmViewModel.SectionField(
            title: R.string.localizable.commonSignatory(preferredLanguages: locale.rLanguages),
            value: walletViewModel
        )
        let feeViewModel = createFeeViewModel(
            fee: fee,
            feeAsset: feeAsset,
            assetPrice: assetPrice,
            locale: locale
        )
        let feeField = MultisigOperationConfirmViewModel.SectionField(
            title: R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages),
            value: feeViewModel
        )
        let signatoryModel = MultisigOperationConfirmViewModel.SignatoryModel(
            wallet: signatoryField,
            fee: feeField
        )

        return .signatory(signatoryModel)
    }

    func createFeeViewModel(
        fee: ExtrinsicFeeProtocol?,
        feeAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        guard let fee, let assetPrice else { return nil }

        let assetInfo = feeAsset.asset.displayInfo

        let feeDecimal = Decimal.fromSubstrateAmount(
            fee.amount,
            precision: assetInfo.assetPrecision
        ) ?? 0.0

        let balanceViewModel = utilityBalanceViewModelFactory.balanceFromPrice(
            feeDecimal,
            priceData: assetPrice
        ).value(for: locale)

        return balanceViewModel
    }

    func createSignatoriesSection(
        pendingOperation: Multisig.PendingOperation,
        multisigWallet: MetaAccountModel,
        signatories: [Multisig.Signatory],
        chain: ChainModel,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel.Section? {
        guard
            let multisigContext = multisigWallet.multisigAccount?.multisig,
            let definition = pendingOperation.multisigDefinition
        else { return nil }

        let title = R.string.localizable.multisigOperationSigningProgressFormat(
            definition.approvals.count,
            multisigContext.threshold,
            preferredLanguages: locale.rLanguages
        )
        let signatoryViewModels = createSignatoriesViewModels(
            from: signatories,
            chain: chain,
            multisigDefinition: definition,
            multisigContext: multisigContext,
            locale: locale
        )
        let listViewModel = SignatoryListViewModel(items: signatoryViewModels)

        return .signatories(.init(signatories: .init(title: title, value: listViewModel)))
    }

    func createSignatoriesViewModels(
        from signatories: [Multisig.Signatory],
        chain: ChainModel,
        multisigDefinition: Multisig.MultisigDefinition,
        multisigContext _: DelegatedAccount.MultisigAccountModel,
        locale: Locale
    ) -> [WalletsCheckmarkViewModel] {
        signatories.compactMap { signatory -> WalletsCheckmarkViewModel? in
            let iconViewModel: IdentifiableImageViewModelProtocol?
            let name: String
            let type: WalletView.ViewModel.TypeInfo
            let accountId: AccountId
            let lineBreakMode: NSLineBreakMode

            switch signatory {
            case let .local(localSignatory):
                iconViewModel = iconViewModelFactory.createIdentifiableDrawableIconViewModel(
                    from: localSignatory.metaAccount.walletIdenticonData,
                    identifier: localSignatory.metaAccount.metaId
                )

                name = localSignatory.metaAccount.chainAccount.name
                type = createWalletTypeInfo(
                    for: localSignatory,
                    locale: locale
                )
                accountId = localSignatory.metaAccount.chainAccount.accountId
                lineBreakMode = .byTruncatingTail

            case let .remote(remoteSignatory):
                guard let address = try? remoteSignatory.accountId.toAddress(using: chain.chainFormat) else {
                    return nil
                }

                iconViewModel = iconViewModelFactory.createIdentifiableDrawableIconViewModel(
                    from: remoteSignatory.accountId,
                    chainFormat: chain.chainFormat
                )
                name = address
                type = .noInfo
                accountId = remoteSignatory.accountId
                lineBreakMode = .byTruncatingMiddle
            }

            let walletInfo = WalletView.ViewModel.WalletInfo(
                icon: iconViewModel,
                name: name,
                lineBreakMode: lineBreakMode
            )
            let walletViewModel = WalletView.ViewModel(
                wallet: walletInfo,
                type: type
            )

            return WalletsCheckmarkViewModel(
                identifier: walletViewModel.wallet.name,
                walletViewModel: walletViewModel,
                checked: multisigDefinition.approvals.contains(accountId)
            )
        }
    }

    func createWalletTypeInfo(
        for localSignatory: Multisig.LocalSignatory,
        locale: Locale
    ) -> WalletView.ViewModel.TypeInfo {
        let type: WalletView.ViewModel.TypeInfo

        switch localSignatory.metaAccount.chainAccount.type {
        case .multisig:
            guard
                let delegate = localSignatory.delegate,
                let iconViewModel = iconViewModelFactory.createIdentifiableDrawableIconViewModel(
                    from: delegate.metaAccount.walletIdenticonData,
                    identifier: localSignatory.metaAccount.metaId
                )
            else {
                return .noInfo
            }

            let delegatedAccountInfo = WalletView.ViewModel.DelegatedAccountInfo(
                networkIcon: iconViewModel,
                type: R.string.localizable.commonSignatory(preferredLanguages: locale.rLanguages),
                pairedAccountIcon: iconViewModel,
                pairedAccountName: delegate.metaAccount.chainAccount.name,
                isNew: false
            )
            type = .multisig(delegatedAccountInfo)

        case .proxied:
            guard let delegate = localSignatory.delegate else { return .noInfo }

            if case let .proxy(proxyType) = delegate.delegationType {
                guard let iconViewModel = iconViewModelFactory.createIdentifiableDrawableIconViewModel(
                    from: delegate.metaAccount.walletIdenticonData,
                    identifier: localSignatory.metaAccount.metaId
                ) else {
                    return .noInfo
                }

                let delegatedAccountInfo = WalletView.ViewModel.DelegatedAccountInfo(
                    networkIcon: iconViewModel,
                    type: proxyType.title(locale: locale),
                    pairedAccountIcon: iconViewModel,
                    pairedAccountName: delegate.metaAccount.chainAccount.name,
                    isNew: false
                )
                type = .proxy(delegatedAccountInfo)
            } else {
                type = .noInfo
            }
        default:
            type = .noInfo
        }

        return type
    }

    func createActions(
        for pendingOperation: Multisig.PendingOperation,
        multisigWallet: MetaAccountModel,
        confirmClosure: @escaping () -> Void,
        callDataAddClosure: @escaping () -> Void
    ) -> [MultisigOperationConfirmViewModel.Action] {
        guard
            let multisigContext = multisigWallet.multisigAccount?.multisig,
            let definition = pendingOperation.multisigDefinition
        else { return [] }

        var actions: [MultisigOperationConfirmViewModel.Action] = []

        let hasCallData = pendingOperation.call != nil
        let createdBySignatory = pendingOperation.isCreator(accountId: multisigContext.signatory)
        let approved = definition.approvals.count >= multisigContext.threshold

        if createdBySignatory, !approved {
            actions.append(.reject(confirmClosure))
        } else if !createdBySignatory, hasCallData {
            actions.append(.approve(confirmClosure))
        }

        if !hasCallData {
            actions.append(.addCallData(callDataAddClosure))
        }

        return actions
    }
}

// MARK: - MultisigOperationConfirmViewModelFactoryProtocol

extension MultisigOperationConfirmViewModelFactory: MultisigOperationConfirmViewModelFactoryProtocol {
    func createViewModel(
        params: MultisigOperationConfirmViewModelParams,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel {
        let originSection = createOriginSection(
            chain: params.chain,
            wallet: params.multisigWallet,
            locale: locale
        )
        let signatorySection = createSignatorySection(
            for: params.pendingOperation,
            multisigWallet: params.multisigWallet,
            signatories: params.signatories,
            fee: params.fee,
            feeAsset: params.feeAsset,
            assetPrice: params.assetPrice,
            locale: locale
        )
        let signatoriesSection = createSignatoriesSection(
            pendingOperation: params.pendingOperation,
            multisigWallet: params.multisigWallet,
            signatories: params.signatories,
            chain: params.chain,
            locale: locale
        )

        let sections = [
            originSection,
            signatorySection,
            signatoriesSection
        ].compactMap { $0 }

        let actions = createActions(
            for: params.pendingOperation,
            multisigWallet: params.multisigWallet,
            confirmClosure: params.confirmClosure,
            callDataAddClosure: params.callDataAddClosure
        )

        return MultisigOperationConfirmViewModel(
            title: R.string.localizable.commonCall(preferredLanguages: locale.rLanguages),
            sections: sections,
            actions: actions
        )
    }

    func createFeeFieldViewModel(
        fee: ExtrinsicFeeProtocol?,
        feeAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?> {
        let feeViewModel = createFeeViewModel(
            fee: fee,
            feeAsset: feeAsset,
            assetPrice: assetPrice,
            locale: locale
        )
        let feeField = MultisigOperationConfirmViewModel.SectionField(
            title: R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages),
            value: feeViewModel
        )

        return feeField
    }
}
