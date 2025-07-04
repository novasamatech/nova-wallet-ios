import Foundation
import SubstrateSdk
import BigInt
import Foundation_iOS

protocol MultisigOperationsViewModelFactoryProtocol {
    func createListViewModel(
        from operations: [Multisig.PendingOperation],
        chains: [ChainModel.Id: ChainModel],
        wallet: MetaAccountModel,
        for locale: Locale
    ) -> MultisigOperationsListViewModel
}

final class MultisigOperationsViewModelFactory {
    private let sectionDateFormatter: LocalizableResource<DateFormatter>
    private let timeFormatter: LocalizableResource<DateFormatter>
    private let networkViewModelFactory: NetworkViewModelFactoryProtocol
    private let displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol?

    init(
        timeFormatter: LocalizableResource<DateFormatter> = DateFormatter.txHistory,
        sectionDateFormatter: LocalizableResource<DateFormatter> = DateFormatter.shortDate,
        networkViewModelFactory: NetworkViewModelFactoryProtocol = NetworkViewModelFactory(),
        displayAddressViewModelFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory(),
        balanceViewModelFactory: BalanceViewModelFactoryProtocol? = nil
    ) {
        self.timeFormatter = timeFormatter
        self.sectionDateFormatter = sectionDateFormatter
        self.networkViewModelFactory = networkViewModelFactory
        self.displayAddressViewModelFactory = displayAddressViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
    }
}

// MARK: - Private

private extension MultisigOperationsViewModelFactory {
    func createOperationTitle(from _: Substrate.CallData?, locale: Locale) -> String {
        let languages = locale.rLanguages

        return R.string.localizable.multisigOperationTypeUnknown(
            preferredLanguages: languages
        )
    }

    func createOperationSubTitle(from _: Substrate.CallData?, locale _: Locale) -> String? {
        nil
    }

    func createSigningProgress(
        from definition: Multisig.MultisigDefinition,
        multisigContext: DelegatedAccount.MultisigAccountModel,
        locale: Locale
    ) -> String {
        let currentApprovals = definition.approvals.count
        let requiredApprovals = multisigContext.threshold

        return R.string.localizable.multisigOperationSigningProgressFormat(
            currentApprovals,
            requiredApprovals,
            preferredLanguages: locale.rLanguages
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

        return if createdByUser {
            .signed(
                TitleIconViewModel(
                    title: R.string.localizable.multisigOperationStatusSigned(preferredLanguages: languages),
                    icon: R.image.iconPositiveCheckmarkFilled()!.tinted(with: R.color.colorIconPositive()!)
                )
            )
        } else if signedByUser {
            .createdByUser(R.string.localizable.multisigOperationStatusCreated(preferredLanguages: languages))
        } else {
            nil
        }
    }

    func createDelegatedAccountModel(
        displayAddress: DisplayAddress
    ) -> DisplayAddressViewModel {
        displayAddressViewModelFactory.createViewModel(from: displayAddress)
    }

    func createViewModel(
        from operation: Multisig.PendingOperation,
        chain: ChainModel,
        wallet: MetaAccountModel,
        for locale: Locale
    ) -> MultisigOperationViewModel? {
        guard
            let multisigContext = wallet.multisigAccount?.multisig,
            let definition = operation.multisigDefinition
        else { return nil }

        let title = createOperationTitle(from: operation.call, locale: locale)
        let subtitle = createOperationSubTitle(from: operation.call, locale: locale)

        let operationDate = Date(timeIntervalSince1970: TimeInterval(operation.timestamp))
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

        let chainIcon = networkViewModelFactory.createDiffableViewModel(from: chain)
        let operationIcon = StaticImageViewModel(image: R.image.iconUnknownOperation()!)

        return MultisigOperationViewModel(
            identifier: operation.identifier,
            chainIcon: chainIcon,
            iconViewModel: operationIcon,
            operationTitle: title,
            operationSubtitle: subtitle,
            amount: nil,
            timeString: timeString,
            signingProgress: signingProgress,
            status: status,
            delegatedAccountModel: nil
        )
    }

    func createSections(
        from operations: [Multisig.PendingOperation],
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
        for operations: (Date, [Multisig.PendingOperation]),
        chains: [ChainModel.Id: ChainModel],
        wallet: MetaAccountModel,
        locale: Locale
    ) -> MultisigOperationSection {
        let operationsViewModels: [MultisigOperationViewModel] = operations.1.compactMap { operation in
            guard let chain = chains[operation.chainId] else { return nil }

            return createViewModel(
                from: operation,
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

    func groupOperationsByDate(_ operations: [Multisig.PendingOperation]) -> [(Date, [Multisig.PendingOperation])] {
        let operationsByDay = Dictionary(grouping: operations) { operation -> DateComponents in
            let date = Date(timeIntervalSince1970: TimeInterval(operation.timestamp))

            return Calendar
                .current
                .dateComponents([.day, .year, .month], from: date)
        }

        let sortedOperations = operationsByDay
            .compactMap { (key, value) -> (Date, [Multisig.PendingOperation])? in
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
        from operations: [Multisig.PendingOperation],
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
