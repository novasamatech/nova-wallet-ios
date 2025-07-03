import Foundation
import SubstrateSdk

struct MultisigOperationConfirmViewModelParams {
    let pendingOperation: Multisig.PendingOperation
    let chain: ChainModel
    let multisigWallet: MetaAccountModel
    let signatories: [Multisig.Signatory]
    let fee: ExtrinsicFeeProtocol?
    let feeAsset: ChainAsset
    let assetPrice: PriceData?
}

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
    let addressIconGenerator: IconGenerating
    let walletIconGenerator: IconGenerating

    init(
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        addressIconGenerator: IconGenerating = PolkadotIconGenerator(),
        walletIconGenerator: IconGenerating = NovaIconGenerator()
    ) {
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.utilityBalanceViewModelFactory = utilityBalanceViewModelFactory
        self.addressIconGenerator = addressIconGenerator
        self.walletIconGenerator = walletIconGenerator
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
        let icon = identiconData.flatMap {
            try? walletIconGenerator.generateFromAccountId($0)
        }
        let iconViewModel = icon.map { DrawableIconViewModel(icon: $0) }

        let walletViewModel = StackCellViewModel(
            details: name,
            imageViewModel: iconViewModel
        )

        return walletViewModel
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
        multisigWallet: MetaAccountModel,
        signatories: [Multisig.Signatory],
        fee: ExtrinsicFeeProtocol?,
        feeAsset: ChainAsset,
        assetPrice: PriceData?,
        locale: Locale
    ) -> MultisigOperationConfirmViewModel.Section? {
        guard
            let multisigContext = multisigWallet.multisigAccount?.multisig,
            let signatory = signatories.first(
                where: { $0.localAccount?.chainAccount.accountId == multisigContext.signatory }
            ),
            case let .local(localSignatory) = signatory
        else { return nil }

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
            locale: locale
        )
        let listViewModel = SignatoryListViewModel(items: signatoryViewModels)

        return .signatories(.init(signatories: .init(title: title, value: listViewModel)))
    }

    func createSignatoriesViewModels(
        from signatories: [Multisig.Signatory],
        chain: ChainModel,
        multisigDefinition: Multisig.MultisigDefinition,
        locale: Locale
    ) -> [WalletsCheckmarkViewModel] {
        signatories.compactMap { signatory -> WalletsCheckmarkViewModel? in
            let iconViewModel: IdentifiableImageViewModelProtocol?
            let name: String
            let type: WalletView.ViewModel.TypeInfo
            let accountId: AccountId

            switch signatory {
            case let .local(localSignatory):
                guard let icon = localSignatory.metaAccount.walletIdenticonData.flatMap({
                    try? walletIconGenerator.generateFromAccountId($0)
                }) else {
                    return nil
                }
                iconViewModel = IdentifiableDrawableIconViewModel(
                    DrawableIconViewModel(icon: icon),
                    identifier: localSignatory.metaAccount.metaId
                )

                name = localSignatory.metaAccount.chainAccount.name
                type = createWalletTypeInfo(
                    for: localSignatory,
                    locale: locale
                )
                accountId = localSignatory.metaAccount.chainAccount.accountId
            case let .remote(remoteSignatory):
                guard
                    let icon = try? addressIconGenerator.generateFromAccountId(
                        remoteSignatory.accountId
                    ),
                    let address = try? remoteSignatory.accountId.toAddress(using: chain.chainFormat)
                else {
                    return nil
                }

                iconViewModel = IdentifiableDrawableIconViewModel(
                    DrawableIconViewModel(icon: icon),
                    identifier: address
                )
                name = address
                type = .noInfo
                accountId = remoteSignatory.accountId
            }

            let walletInfo = WalletView.ViewModel.WalletInfo(
                icon: iconViewModel,
                name: name
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
                let icon = delegate.metaAccount.walletIdenticonData.flatMap({
                    try? walletIconGenerator.generateFromAccountId($0)
                }) else {
                return .regular("")
            }

            let iconViewModel = IdentifiableDrawableIconViewModel(
                DrawableIconViewModel(icon: icon),
                identifier: localSignatory.metaAccount.metaId
            )

            let delegatedAccountInfo = WalletView.ViewModel.DelegatedAccountInfo(
                networkIcon: iconViewModel,
                type: R.string.localizable.commonSignatory(preferredLanguages: locale.rLanguages),
                pairedAccountIcon: iconViewModel,
                pairedAccountName: delegate.metaAccount.chainAccount.name,
                isNew: false
            )
            type = .multisig(delegatedAccountInfo)
        case .proxied:
            guard let delegate = localSignatory.delegate else { return .regular("") }

            if case let .proxy(proxyType) = delegate.delegationType {
                guard let icon = delegate.metaAccount.walletIdenticonData.flatMap({
                    try? walletIconGenerator.generateFromAccountId($0)
                }) else {
                    return .regular("")
                }

                let iconViewModel = IdentifiableDrawableIconViewModel(
                    DrawableIconViewModel(icon: icon),
                    identifier: localSignatory.metaAccount.metaId
                )

                let delegatedAccountInfo = WalletView.ViewModel.DelegatedAccountInfo(
                    networkIcon: iconViewModel,
                    type: proxyType.title(locale: locale),
                    pairedAccountIcon: iconViewModel,
                    pairedAccountName: delegate.metaAccount.chainAccount.name,
                    isNew: false
                )
                type = .proxy(delegatedAccountInfo)
            } else {
                type = .regular("")
            }
        default:
            type = .regular("")
        }

        return type
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

        return MultisigOperationConfirmViewModel(
            title: R.string.localizable.commonCall(preferredLanguages: locale.rLanguages),
            sections: sections
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
