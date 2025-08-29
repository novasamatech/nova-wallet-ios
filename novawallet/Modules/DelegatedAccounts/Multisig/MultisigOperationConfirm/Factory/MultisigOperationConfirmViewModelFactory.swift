import Foundation
import SubstrateSdk
import BigInt

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

    func createAmountViewModel(
        from callDefinition: FormattedCall.Definition,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol?
}

final class MultisigOperationConfirmViewModelFactory {
    let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    let iconViewModelFactory: IconViewModelFactoryProtocol

    init(
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        iconViewModelFactory: IconViewModelFactoryProtocol = IconViewModelFactory()
    ) {
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
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

    func createBalanceViewModel(
        for amount: BigUInt,
        chainAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let assetInfo = chainAsset.asset.displayInfo

        let decimal = amount.decimal(assetInfo: assetInfo)

        let balanceViewModel = balanceViewModelFactoryFacade.balanceFromPrice(
            targetAssetInfo: chainAsset.asset.displayInfo,
            amount: decimal,
            priceData: assetPrice
        ).value(for: locale)

        return balanceViewModel
    }

    func createOriginSection(
        chain: ChainModel,
        wallet: MetaAccountModel,
        delegatedAccount: FormattedCall.Account?,
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

        var delegatedField: MultisigOperationConfirmViewModel.SectionField<DisplayAddressViewModel>?

        if
            let delegatedAccount,
            let delegatedViewModel = try? displayAddressViewModelFactory.createViewModel(
                from: delegatedAccount,
                chain: chain
            ) {
            delegatedField = MultisigOperationConfirmViewModel.SectionField(
                title: R.string.localizable.delegatedAccountOnBehalfOf(preferredLanguages: locale.rLanguages),
                value: delegatedViewModel
            )
        }

        let originViewModel = MultisigOperationConfirmViewModel.OriginModel(
            network: networkField,
            wallet: walletField,
            delegatedAccount: delegatedField
        )

        return .origin(originViewModel)
    }

    func createRecipientSection(
        chain: ChainModel,
        callDefinition: FormattedCall.Definition?,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel.Section? {
        guard
            case let .transfer(transfer) = callDefinition,
            let recipientViewModel = try? displayAddressViewModelFactory.createViewModel(
                from: transfer.account,
                chain: chain
            )
        else { return nil }

        let fieldModel = MultisigOperationConfirmViewModel.SectionField(
            title: R.string.localizable.commonRecipient(preferredLanguages: locale.rLanguages),
            value: recipientViewModel
        )

        let sectionViewModel = MultisigOperationConfirmViewModel.RecipientModel(
            recipient: fieldModel
        )

        return .recipient(sectionViewModel)
    }

    func createSignatorySection(
        for pendingOperation: Multisig.PendingOperationProxyModel,
        multisigWallet: MetaAccountModel,
        signatories: [Multisig.Signatory],
        fee: ExtrinsicFeeProtocol?,
        feeAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel.Section? {
        guard
            let multisigContext = multisigWallet.getMultisig(
                for: feeAsset.chain
            ),
            let definition = pendingOperation.operation.multisigDefinition,
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

        let operationProperties = createOperationProperties(
            for: pendingOperation,
            multisigContext: multisigContext,
            definition: definition
        )

        var feeField: MultisigOperationConfirmViewModel.SectionField<BalanceViewModelProtocol?>?

        if operationProperties.canShowFee {
            let feeViewModel = createFeeViewModel(
                fee: fee,
                feeAsset: feeAsset,
                assetPrice: assetPrice,
                locale: locale
            )
            feeField = MultisigOperationConfirmViewModel.SectionField(
                title: R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages),
                value: feeViewModel
            )
        }

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
        guard let fee else { return nil }

        return createBalanceViewModel(
            for: fee.amount,
            chainAsset: feeAsset,
            assetPrice: assetPrice,
            locale: locale
        )
    }

    func createAmount(
        from callDefinition: FormattedCall.Definition?,
        operationAssetPriceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        guard
            let amount = callDefinition?.amount,
            let chainAsset = callDefinition?.amountAsset
        else { return nil }

        let amountDecimal = amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return balanceViewModelFactoryFacade.spendingAmountFromPrice(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            amount: amountDecimal,
            priceData: operationAssetPriceData
        ).value(for: locale)
    }

    func createSignatoriesSection(
        pendingOperation: Multisig.PendingOperation,
        multisigWallet: MetaAccountModel,
        signatories: [Multisig.Signatory],
        chain: ChainModel,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel.Section? {
        guard
            let multisigContext = multisigWallet.getMultisig(
                for: chain
            ),
            let definition = pendingOperation.multisigDefinition
        else { return nil }

        let title = R.string.localizable.multisigOperationSignatoriesProgressFormat(
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

    func createFullDetailsSection(locale: Locale) -> MultisigOperationConfirmViewModel.Section {
        let model = MultisigOperationConfirmViewModel.FullDetailsModel(
            title: R.string.localizable.commonFullDetails(preferredLanguages: locale.rLanguages),
            value: ""
        )

        return .fullDetails(model)
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
            let accountAddress: AccountAddress
            let lineBreakMode: NSLineBreakMode

            switch signatory {
            case let .local(localSignatory):
                guard let address = try? localSignatory.metaAccount.chainAccount.accountId.toAddress(
                    using: chain.chainFormat
                ) else {
                    return nil
                }
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
                accountAddress = address
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
                accountAddress = address
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
                identifier: accountAddress,
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

            if case let .proxy(proxyModel) = delegate.delegationType {
                guard let iconViewModel = iconViewModelFactory.createIdentifiableDrawableIconViewModel(
                    from: delegate.metaAccount.walletIdenticonData,
                    identifier: localSignatory.metaAccount.metaId
                ) else {
                    return .noInfo
                }

                let delegatedAccountInfo = WalletView.ViewModel.DelegatedAccountInfo(
                    networkIcon: iconViewModel,
                    type: proxyModel.type.title(locale: locale),
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
        for pendingOperation: Multisig.PendingOperationProxyModel,
        multisigWallet: MetaAccountModel,
        chain: ChainModel,
        locale: Locale,
        confirmClosure: @escaping () -> Void,
        callDataAddClosure: @escaping () -> Void
    ) -> [MultisigOperationConfirmViewModel.Action] {
        guard
            let multisigContext = multisigWallet.getMultisig(for: chain),
            let definition = pendingOperation.operation.multisigDefinition
        else { return [] }

        var actions: [MultisigOperationConfirmViewModel.Action] = []

        let operationProperties = createOperationProperties(
            for: pendingOperation,
            multisigContext: multisigContext,
            definition: definition
        )

        if operationProperties.canReject {
            let action = MultisigOperationConfirmViewModel.Action(
                title: R.string.localizable.commonReject(preferredLanguages: locale.rLanguages),
                type: .reject,
                actionClosure: confirmClosure
            )
            actions.append(action)
        } else if operationProperties.canApprove {
            let title = if operationProperties.willExecute {
                R.string.localizable.commonApproveAndExecute(preferredLanguages: locale.rLanguages)
            } else {
                R.string.localizable.commonApprove(preferredLanguages: locale.rLanguages)
            }
            let action = MultisigOperationConfirmViewModel.Action(
                title: title,
                type: .approve,
                actionClosure: confirmClosure
            )
            actions.append(action)
        }

        if !operationProperties.hasCall {
            let action = MultisigOperationConfirmViewModel.Action(
                title: R.string.localizable.enterCallDataDetailsButtonTitle(preferredLanguages: locale.rLanguages),
                type: .addCallData,
                actionClosure: callDataAddClosure
            )
            actions.append(action)
        }

        return actions
    }

    func createTitle(
        for formattedCall: FormattedCall?,
        locale: Locale
    ) -> String {
        switch formattedCall?.definition {
        case let .general(general):
            general.callPath.callName.displayCall
        case let .batch(batch):
            batch.type.callDescription.value(for: locale)
        case .transfer:
            R.string.localizable.transferTitle(
                preferredLanguages: locale.rLanguages
            )
        case nil:
            R.string.localizable.multisigOperationTypeUnknown(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createOperationProperties(
        for pendingOperation: Multisig.PendingOperationProxyModel,
        multisigContext: DelegatedAccount.MultisigAccountModel,
        definition: Multisig.MultisigDefinition
    ) -> OperationProperties {
        let hasCall = pendingOperation.operation.call != nil
            || pendingOperation.formattedModel?.decoded != nil
        let createdBySignatory = pendingOperation.operation.isCreator(accountId: multisigContext.signatory)
        let approved = definition.approvals.count >= multisigContext.threshold
        let willExecute = (multisigContext.threshold - definition.approvals.count) == 1

        return OperationProperties(
            hasCall: hasCall,
            createdBySignatory: createdBySignatory,
            approved: approved,
            willExecute: willExecute
        )
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
            delegatedAccount: params.pendingOperation.formattedModel?.delegatedAccount,
            locale: locale
        )
        let recipientSection = createRecipientSection(
            chain: params.chain,
            callDefinition: params.pendingOperation.formattedModel?.definition,
            locale: locale
        )
        let signatorySection = createSignatorySection(
            for: params.pendingOperation,
            multisigWallet: params.multisigWallet,
            signatories: params.signatories,
            fee: params.fee,
            feeAsset: params.chainAsset,
            assetPrice: params.utilityAssetPrice,
            locale: locale
        )
        let signatoriesSection = createSignatoriesSection(
            pendingOperation: params.pendingOperation.operation,
            multisigWallet: params.multisigWallet,
            signatories: params.signatories,
            chain: params.chain,
            locale: locale
        )
        let fullDetailsSection = createFullDetailsSection(locale: locale)

        let sections = [
            originSection,
            recipientSection,
            signatorySection,
            signatoriesSection,
            fullDetailsSection
        ].compactMap { $0 }

        let actions = createActions(
            for: params.pendingOperation,
            multisigWallet: params.multisigWallet,
            chain: params.chain,
            locale: locale,
            confirmClosure: params.confirmClosure,
            callDataAddClosure: params.callDataAddClosure
        )

        let title = createTitle(for: params.pendingOperation.formattedModel, locale: locale)

        let amountViewModel = createAmount(
            from: params.pendingOperation.formattedModel?.definition,
            operationAssetPriceData: params.operationAssetPrice,
            locale: locale
        )

        return MultisigOperationConfirmViewModel(
            title: title,
            amount: amountViewModel,
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

    func createAmountViewModel(
        from callDefinition: FormattedCall.Definition,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        createAmount(
            from: callDefinition,
            operationAssetPriceData: priceData,
            locale: locale
        )
    }
}

// MARK: - Private types

private struct OperationProperties {
    let hasCall: Bool
    let createdBySignatory: Bool
    let approved: Bool
    let willExecute: Bool

    var canShowFee: Bool {
        canApprove || canReject
    }

    var canApprove: Bool {
        !createdBySignatory && hasCall
    }

    var canReject: Bool {
        createdBySignatory && !approved
    }
}
