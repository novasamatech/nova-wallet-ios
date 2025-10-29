import Foundation
import SubstrateSdk
import BigInt
import Foundation_iOS

protocol MultisigOperationsViewModelFactoryProtocol {
    func createListViewModel(
        from operations: [Multisig.PendingOperationProxyModel],
        chains: [ChainModel.Id: ChainModel],
        wallet: MetaAccountModel,
        for locale: Locale
    ) -> MultisigOperationsListViewModel
}

final class MultisigOperationsViewModelFactory {
    private let calendar = Calendar.current
    private let sectionDateFormatter: LocalizableResource<DateFormatter>
    private let timeFormatter: LocalizableResource<DateFormatter>
    private let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol
    private let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    private let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(
        timeFormatter: LocalizableResource<DateFormatter> = DateFormatter.txHistory,
        sectionDateFormatter: LocalizableResource<DateFormatter> = DateFormatter.txHistoryDate.localizableResource(),
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory(),
        networkViewModelFactory: NetworkViewModelFactoryProtocol = NetworkViewModelFactory(),
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory(),
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    ) {
        self.timeFormatter = timeFormatter
        self.sectionDateFormatter = sectionDateFormatter
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.networkViewModelFactory = networkViewModelFactory
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }
}

// MARK: - Private

private extension MultisigOperationsViewModelFactory {
    func createOperationTitle(
        from call: FormattedCall?,
        locale: Locale
    ) -> String {
        guard let call else {
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.multisigOperationTypeUnknown()
        }

        return switch call.definition {
        case let .general(general):
            general.callPath.callName.displayCall
        case let .batch(batch):
            batch.type.callDescription.value(for: locale)
        case .transfer:
            R.string(preferredLanguages: locale.rLanguages).localizable.transferTitle()
        }
    }

    func createOperationSubtitle(
        from call: FormattedCall?,
        chain: ChainModel,
        locale: Locale
    ) -> String? {
        guard let call else {
            return nil
        }

        return switch call.definition {
        case let .general(general):
            general.callPath.moduleName.displayCall
        case let .batch(batch):
            batch.type.path.moduleName.displayCall
        case let .transfer(transfer):
            if let address = try? transfer.account.accountId.toAddress(
                using: chain.chainFormat
            ) {
                R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.walletHistoryTransferOutgoingDetails(
                    address.truncated
                )
            } else {
                nil
            }
        }
    }

    func createSigningProgress(
        from definition: Multisig.MultisigDefinition,
        multisigContext: DelegatedAccount.MultisigAccountModel,
        locale: Locale
    ) -> String {
        let currentApprovals = definition.approvals.count
        let requiredApprovals = multisigContext.threshold

        return R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.multisigOperationSigningProgressFormat(
            currentApprovals,
            requiredApprovals
        ).uppercased()
    }

    func createOperationStatus(
        definition: Multisig.MultisigDefinition,
        multisigContext: DelegatedAccount.MultisigAccountModel,
        locale: Locale
    ) -> MultisigOperationViewModel.Status? {
        let languages = locale.rLanguages

        let signedByUser = definition.signedBy(accountId: multisigContext.signatory)
        let createdByUser = definition.createdBy(accountId: multisigContext.signatory)

        if createdByUser {
            return .createdByUser(
                R.string(preferredLanguages: languages).localizable.multisigOperationStatusCreated()
            )
        } else if signedByUser {
            return .signed(
                TitleIconViewModel(
                    title: R.string(preferredLanguages: languages).localizable.multisigOperationStatusSigned(),
                    icon: R.image.iconCheckmarkFilled()!.tinted(with: R.color.colorIconPositive()!)
                )
            )
        } else {
            return nil
        }
    }

    func createAmount(
        from callDefinition: FormattedCall.Definition?,
        locale: Locale
    ) -> String? {
        guard case let .transfer(transfer) = callDefinition else { return nil }

        let amount = transfer.amount

        let amountDecimal = amount.decimal(assetInfo: transfer.asset.assetDisplayInfo)

        return balanceViewModelFactoryFacade.spendingAmountFromPrice(
            targetAssetInfo: transfer.asset.assetDisplayInfo,
            amount: amountDecimal,
            priceData: nil
        ).value(for: locale).amount
    }

    func createDelegatedAccount(
        from delegatedAccount: FormattedCall.Account?,
        chain: ChainModel,
        locale: Locale
    ) -> MultisigOperationViewModel.DelegatedAccount? {
        guard
            let delegatedAccount,
            let displayAddressModel = try? displayAddressViewModelFactory.createViewModel(
                from: delegatedAccount,
                chain: chain
            )
        else { return nil }

        return MultisigOperationViewModel.DelegatedAccount(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.delegatedAccountOnBehalfOf(),
            model: displayAddressModel
        )
    }

    func createOperationIcon(
        for callDefinition: FormattedCall.Definition?,
        chain: ChainModel
    ) -> ImageViewModelProtocol {
        guard let callDefinition else {
            return StaticImageViewModel(image: R.image.iconUnknownOperation()!)
        }

        switch callDefinition {
        case .transfer:
            return StaticImageViewModel(image: R.image.iconOutgoingTransfer()!)
        case .general, .batch:
            return assetIconViewModelFactory.createAssetIconViewModel(
                for: chain.utilityChainAsset()?.asset.icon,
                with: .white
            )
        }
    }

    func createViewModel(
        from operationModel: Multisig.PendingOperationProxyModel,
        chain: ChainModel,
        wallet: MetaAccountModel,
        for locale: Locale
    ) -> MultisigOperationViewModel? {
        guard
            let multisigContext = wallet.getMultisig(for: chain),
            let definition = operationModel.operation.multisigDefinition
        else { return nil }

        let title = createOperationTitle(from: operationModel.formattedModel, locale: locale)
        let subtitle = createOperationSubtitle(
            from: operationModel.formattedModel,
            chain: chain,
            locale: locale
        )

        let amount = createAmount(
            from: operationModel.formattedModel?.definition,
            locale: locale
        )
        let operationDate = Date(timeIntervalSince1970: TimeInterval(operationModel.timestamp))
        let timeString = timeFormatter.value(for: locale).string(from: operationDate)

        let signingProgress = createSigningProgress(
            from: definition,
            multisigContext: multisigContext,
            locale: locale
        )
        let status = createOperationStatus(
            definition: definition,
            multisigContext: multisigContext,
            locale: locale
        )

        let delegatedAccount = createDelegatedAccount(
            from: operationModel.formattedModel?.delegatedAccount,
            chain: chain,
            locale: locale
        )

        let chainIcon = networkViewModelFactory.createDiffableViewModel(from: chain)

        let operationIcon = createOperationIcon(
            for: operationModel.formattedModel?.definition,
            chain: chain
        )

        return MultisigOperationViewModel(
            identifier: operationModel.identifier,
            chainIcon: chainIcon,
            iconViewModel: operationIcon,
            operationTitle: title,
            operationSubtitle: subtitle,
            amount: amount,
            timeString: timeString,
            signingProgress: signingProgress,
            status: status,
            delegatedAccountModel: delegatedAccount
        )
    }

    func createSections(
        from operations: [Multisig.PendingOperationProxyModel],
        chains: [ChainModel.Id: ChainModel],
        wallet: MetaAccountModel,
        for locale: Locale
    ) -> [MultisigOperationSection] {
        groupOperationsByDate(operations)
            .map {
                createSection(
                    for: $0,
                    chains: chains,
                    wallet: wallet,
                    locale: locale
                )
            }
    }

    func createSection(
        for operations: (Date, [Multisig.PendingOperationProxyModel]),
        chains: [ChainModel.Id: ChainModel],
        wallet: MetaAccountModel,
        locale: Locale
    ) -> MultisigOperationSection {
        let operationsViewModels: [MultisigOperationViewModel] = operations.1.compactMap { operationModel in
            guard let chain = chains[operationModel.operation.chainId] else { return nil }

            return createViewModel(
                from: operationModel,
                chain: chain,
                wallet: wallet,
                for: locale
            )
        }

        let sectionTitle = sectionDateFormatter.value(for: locale).string(from: operations.0)

        return MultisigOperationSection(
            title: sectionTitle,
            operations: operationsViewModels
        )
    }

    func groupOperationsByDate(
        _ operations: [Multisig.PendingOperationProxyModel]
    ) -> [(Date, [Multisig.PendingOperationProxyModel])] {
        let operationsByDay = Dictionary(grouping: operations) { operation -> DateComponents in
            let date = Date(timeIntervalSince1970: TimeInterval(operation.timestamp))

            return calendar.dateComponents([.day, .year, .month], from: date)
        }

        let sortedOperations = operationsByDay
            .compactMap { (key, value) -> (Date, [Multisig.PendingOperationProxyModel])? in
                var mutComponents = key
                mutComponents.calendar = Calendar.current

                guard let date = mutComponents.date else { return nil }

                return (date, value)
            }
            .sorted { $0.0 > $1.0 }

        return sortedOperations
    }
}

// MARK: - MultisigOperationsViewModelFactoryProtocol

extension MultisigOperationsViewModelFactory: MultisigOperationsViewModelFactoryProtocol {
    func createListViewModel(
        from operations: [Multisig.PendingOperationProxyModel],
        chains: [ChainModel.Id: ChainModel],
        wallet: MetaAccountModel,
        for locale: Locale
    ) -> MultisigOperationsListViewModel {
        guard !operations.isEmpty else {
            return .empty
        }

        let sections = createSections(
            from: operations,
            chains: chains,
            wallet: wallet,
            for: locale
        )

        return .sections(sections)
    }
}
