import Foundation
import SubstrateSdk
import Foundation_iOS
import BigInt

protocol CollatorStkYourCollatorsViewModelFactoryProtocol {
    func createViewModel(
        for selectedAccountId: AccountId,
        collators: [CollatorStakingSelectionInfoProtocol],
        delegator: CollatorStakingDelegator,
        locale: Locale
    ) throws -> CollatorStkYourCollatorsListViewModel
}

final class CollatorStkYourCollatorsViewModelFactory {
    let balanceViewModeFactory: BalanceViewModelFactoryProtocol
    let assetPrecision: Int16
    let chainFormat: ChainFormat

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        balanceViewModeFactory: BalanceViewModelFactoryProtocol,
        assetPrecision: Int16,
        chainFormat: ChainFormat
    ) {
        self.balanceViewModeFactory = balanceViewModeFactory
        self.assetPrecision = assetPrecision
        self.chainFormat = chainFormat
    }

    private func createCollatorViewModel(
        for model: CollatorStakingSelectionInfoProtocol,
        staked: BigUInt,
        status: CollatorStakingDelegationStatus,
        aprFormatter: NumberFormatter,
        locale: Locale
    ) throws -> CollatorSelectionViewModel {
        let address = try model.accountId.toAddress(using: chainFormat)
        let iconViewModel = try iconGenerator.generateFromAccountId(model.accountId)
        let titleViewModel = DisplayAddressViewModel(
            address: address,
            name: model.identity?.displayName,
            imageViewModel: nil
        )

        let detailsName = R.string(preferredLanguages: locale.rLanguages).localizable.commonStakedPrefix()

        let stakedDecimal = Decimal.fromSubstrateAmount(staked, precision: assetPrecision) ?? 0
        let details = balanceViewModeFactory.amountFromValue(stakedDecimal).value(for: locale)

        let rewards = model.apr.flatMap { aprFormatter.stringFromDecimal($0) } ?? ""

        return CollatorSelectionViewModel(
            identifier: model.accountId,
            iconViewModel: iconViewModel,
            collator: titleViewModel,
            detailsName: detailsName,
            details: details,
            sortedByTitle: rewards,
            sortedByDetails: "",
            hasWarning: status == .notRewarded
        )
    }

    private func createSectionsFromOrder(
        _ order: [CollatorStakingDelegationStatus],
        mapping: [CollatorStakingDelegationStatus: [CollatorSelectionViewModel]]
    ) -> [CollatorStkYourCollatorListSection] {
        order.compactMap { status in
            if let collators = mapping[status], !collators.isEmpty {
                return CollatorStkYourCollatorListSection(status: status, collators: collators)
            } else {
                return nil
            }
        }
    }
}

extension CollatorStkYourCollatorsViewModelFactory: CollatorStkYourCollatorsViewModelFactoryProtocol {
    func createViewModel(
        for selectedAccountId: AccountId,
        collators: [CollatorStakingSelectionInfoProtocol],
        delegator: CollatorStakingDelegator,
        locale: Locale
    ) throws -> CollatorStkYourCollatorsListViewModel {
        let aprFormatter = NumberFormatter.percent

        let stakes = delegator.delegationsDict()

        let collatorsMapping = try collators
            .sorted(by: {
                let stake1 = stakes[$0.accountId] ?? 0
                let stake2 = stakes[$1.accountId] ?? 0

                return stake1 > stake2
            })
            .reduce(
                into: [CollatorStakingDelegationStatus: [CollatorSelectionViewModel]]()) { result, item in
                let delegatorStake = stakes[item.accountId] ?? 0
                let status = item.status(
                    for: selectedAccountId,
                    delegatorModel: delegator,
                    stake: delegatorStake
                )

                let viewModel = try createCollatorViewModel(
                    for: item,
                    staked: delegatorStake,
                    status: status,
                    aprFormatter: aprFormatter,
                    locale: locale
                )

                result[status] = (result[status] ?? []) + [viewModel]
            }

        let sectionsOrder: [CollatorStakingDelegationStatus] = [
            .rewarded, .notRewarded, .notElected, .pending
        ]

        let sections = createSectionsFromOrder(sectionsOrder, mapping: collatorsMapping)

        let notRewardedCollators = collatorsMapping[.notRewarded] ?? []
        let notElectedCollators = collatorsMapping[.notElected] ?? []
        let hasCollatorWithoutReward = !notRewardedCollators.isEmpty || !notElectedCollators.isEmpty

        return CollatorStkYourCollatorsListViewModel(
            hasCollatorWithoutRewards: hasCollatorWithoutReward,
            sections: sections
        )
    }
}
