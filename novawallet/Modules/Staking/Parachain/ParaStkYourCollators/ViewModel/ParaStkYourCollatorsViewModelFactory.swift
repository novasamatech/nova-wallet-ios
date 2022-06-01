import Foundation
import SubstrateSdk
import SoraFoundation
import BigInt

protocol ParaStkYourCollatorsViewModelFactoryProtocol {
    func createViewModel(
        for selectedAccountId: AccountId,
        collators: [CollatorSelectionInfo],
        delegator: ParachainStaking.Delegator,
        locale: Locale
    ) throws -> ParaStkYourCollatorsListViewModel
}

final class ParaStkYourCollatorsViewModelFactory {
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
        for model: CollatorSelectionInfo,
        staked: BigUInt,
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

        let detailsName = R.string.localizable.commonStakedPrefix(preferredLanguages: locale.rLanguages)

        let stakedDecimal = Decimal.fromSubstrateAmount(staked, precision: assetPrecision) ?? 0
        let details = balanceViewModeFactory.amountFromValue(stakedDecimal).value(for: locale)

        let rewards = model.apr.flatMap { aprFormatter.stringFromDecimal($0) } ?? ""

        return CollatorSelectionViewModel(
            iconViewModel: iconViewModel,
            collator: titleViewModel,
            detailsName: detailsName,
            details: details,
            sortedByTitle: rewards,
            sortedByDetails: ""
        )
    }

    private func createSectionsFromOrder(
        _ order: [ParaStkDelegationStatus],
        mapping: [ParaStkDelegationStatus: [CollatorSelectionViewModel]]
    ) -> [ParaStkYourCollatorListSection] {
        order.compactMap { status in
            if let collators = mapping[status], !collators.isEmpty {
                return ParaStkYourCollatorListSection(status: status, collators: collators)
            } else {
                return nil
            }
        }
    }
}

extension ParaStkYourCollatorsViewModelFactory: ParaStkYourCollatorsViewModelFactoryProtocol {
    func createViewModel(
        for selectedAccountId: AccountId,
        collators: [CollatorSelectionInfo],
        delegator: ParachainStaking.Delegator,
        locale: Locale
    ) throws -> ParaStkYourCollatorsListViewModel {
        let aprFormatter = NumberFormatter.percent

        let stakes = delegator.delegationsDic()

        let collatorsMapping = try collators
            .sorted(by: {
                let stake1 = stakes[$0.accountId]?.amount ?? 0
                let stake2 = stakes[$1.accountId]?.amount ?? 0

                return stake1 > stake2
            })
            .reduce(
                into: [ParaStkDelegationStatus: [CollatorSelectionViewModel]]()) { result, item in
                let delegatorStake = stakes[item.accountId]?.amount ?? 0
                let status = item.status(for: selectedAccountId, stake: delegatorStake)

                let viewModel = try createCollatorViewModel(
                    for: item,
                    staked: delegatorStake,
                    aprFormatter: aprFormatter,
                    locale: locale
                )

                result[status] = (result[status] ?? []) + [viewModel]
            }

        let sectionsOrder: [ParaStkDelegationStatus] = [
            .rewarded, .notRewarded, .notElected, .pending
        ]

        let sections = createSectionsFromOrder(sectionsOrder, mapping: collatorsMapping)

        let notRewardedCollators = collatorsMapping[.notRewarded] ?? []
        let notElectedCollators = collatorsMapping[.notElected] ?? []
        let hasCollatorWithoutReward = !notRewardedCollators.isEmpty || !notElectedCollators.isEmpty

        return ParaStkYourCollatorsListViewModel(
            hasCollatorWithoutRewards: hasCollatorWithoutReward,
            sections: sections
        )
    }
}
