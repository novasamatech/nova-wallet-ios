import UIKit
import Foundation_iOS
import UIKit_iOS
import BigInt

struct ModalInfoFactory {
    static let rowHeight: CGFloat = 50.0
    static let headerHeight: CGFloat = 40.0
    static let footerHeight: CGFloat = 0.0

    typealias LockSortingViewModel = (value: Decimal, viewModel: LocalizableResource<StakingAmountViewModel>)
    typealias LocksSortingViewModel = [LockSortingViewModel]

    static func createParaStkRewardDetails(
        for maxReward: Decimal,
        avgReward: Decimal,
        symbol: String
    ) -> UIViewController {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingEstimateEarningTitle_v190(symbol)
        }

        let maxRewardTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.parastkRewardInfoMax()
        }

        let avgRewardTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.parastkRewardInfoAvg()
        }

        return createRewardDetails(
            for: maxReward,
            avgReward: avgReward,
            title: title,
            maxRewardTitle: maxRewardTitle,
            avgRewardTitle: avgRewardTitle
        )
    }

    static func createRewardDetails(
        for maxReward: Decimal,
        avgReward: Decimal
    ) -> UIViewController {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingRewardInfoTitle()
        }

        let maxRewardTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingRewardInfoMax()
        }

        let avgRewardTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingRewardInfoAvg()
        }

        return createRewardDetails(
            for: maxReward,
            avgReward: avgReward,
            title: title,
            maxRewardTitle: maxRewardTitle,
            avgRewardTitle: avgRewardTitle
        )
    }

    private static func createRewardDetails(
        for maxReward: Decimal,
        avgReward: Decimal,
        title: LocalizableResource<String>,
        maxRewardTitle: LocalizableResource<String>,
        avgRewardTitle: LocalizableResource<String>
    ) -> UIViewController {
        let viewController: ModalPickerViewController<DetailsDisplayTableViewCell, TitleWithSubtitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)
        viewController.cellHeight = Self.rowHeight
        viewController.headerHeight = Self.headerHeight
        viewController.footerHeight = Self.footerHeight
        viewController.headerBorderType = []
        viewController.separatorStyle = .singleLine
        viewController.allowsSelection = false
        viewController.hasCloseItem = false

        viewController.localizedTitle = title

        viewController.cellNib = UINib(resource: R.nib.detailsDisplayTableViewCell)
        viewController.modalPresentationStyle = .custom

        let formatter = NumberFormatter.percent.localizableResource()

        let maxViewModel: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
            let title = maxRewardTitle.value(for: locale)
            let details = formatter.value(for: locale).stringFromDecimal(maxReward) ?? ""

            return TitleWithSubtitleViewModel(title: title, subtitle: details)
        }

        let avgViewModel: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
            let title = avgRewardTitle.value(for: locale)
            let details = formatter.value(for: locale).stringFromDecimal(avgReward) ?? ""

            return TitleWithSubtitleViewModel(title: title, subtitle: details)
        }

        let viewModels = [maxViewModel, avgViewModel]
        viewController.viewModels = viewModels

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(viewModels.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createFromBalanceContext(
        _ balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        precision: Int16
    ) -> UIViewController {
        let viewController: ModalPickerViewController<BottomSheetInfoBalanceCell, StakingAmountViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)
        viewController.cellHeight = Self.rowHeight
        viewController.headerHeight = Self.headerHeight
        viewController.footerHeight = Self.footerHeight
        viewController.headerBorderType = []
        viewController.allowsSelection = false
        viewController.hasCloseItem = false
        viewController.separatorStyle = .singleLine
        viewController.separatorColor = R.color.colorDivider()

        viewController.localizedTitle = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.walletBalanceLocked()
        }

        viewController.modalPresentationStyle = .custom

        let viewModels = createViewModelsForContext(
            balanceContext,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter,
            precision: precision
        )

        viewController.viewModels = viewModels

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(viewModels.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    private static func createViewModelsForContext(
        _ balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        precision: Int16
    ) -> [LocalizableResource<StakingAmountViewModel>] {
        let reserved: LocksSortingViewModel = createReservedViewModel(
            balanceContext: balanceContext,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter,
            precision: precision
        )

        let externalBalances = createExternalBalancesViewModel(
            balanceContext: balanceContext,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter
        )

        let balanceLockKnownModels: LocksSortingViewModel = createLockViewModel(
            from: balanceContext.balanceLocks.mainLocks(),
            balanceContext: balanceContext,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter,
            precision: precision
        )

        let balanceLockUnknownModels: LocksSortingViewModel = createLockViewModel(
            from: balanceContext.balanceLocks.auxLocks(),
            balanceContext: balanceContext,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter,
            precision: precision
        )

        let balanceHolds = createHoldsViewModel(
            from: balanceContext.balanceHolds,
            balanceContext: balanceContext,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter,
            precision: precision
        )

        return (balanceLockKnownModels + balanceLockUnknownModels + balanceHolds + externalBalances + reserved)
            .sorted { viewModel1, viewModel2 in
                viewModel1.value >= viewModel2.value
            }.map(\.viewModel)
    }

    private static func createLockViewModel(
        from locks: AssetLocks,
        balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        precision: Int16
    ) -> LocksSortingViewModel {
        locks.map { lock in
            let lockAmount = Decimal.fromSubstrateAmount(
                lock.amount,
                precision: precision
            ) ?? 0.0

            let price = lockAmount * balanceContext.price

            let viewModel = LocalizableResource<StakingAmountViewModel> { locale in
                let formatter = priceFormatter.value(for: locale)
                let amountFormatter = amountFormatter.value(for: locale)

                let title: String = {
                    guard let mainTitle = lock.lockType?.displayType.value(for: locale) else {
                        return lock.displayModuleAndIdTitle ?? ""
                    }
                    return mainTitle
                }()

                let priceString = balanceContext.price == 0.0 ? nil : formatter.stringFromDecimal(price)
                let amountString = amountFormatter.stringFromDecimal(lockAmount) ?? ""

                let balance = BalanceViewModel(
                    amount: amountString,
                    price: priceString
                )

                return StakingAmountViewModel(title: title, balance: balance)
            }

            return (price, viewModel)
        }
    }

    private static func createHoldsViewModel(
        from holds: [AssetHold],
        balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        precision: Int16
    ) -> LocksSortingViewModel {
        holds.map { hold in
            let holdAmount = Decimal.fromSubstrateAmount(
                hold.amount,
                precision: precision
            ) ?? 0.0

            return createLockFieldViewModel(
                amount: holdAmount,
                price: balanceContext.price,
                localizedTitle: LocalizableResource { locale in
                    hold.displayTitle(for: locale)
                },
                amountFormatter: amountFormatter,
                priceFormatter: priceFormatter
            )
        }.flatMap { $0 }
    }

    private static func createExternalBalancesViewModel(
        balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>
    ) -> LocksSortingViewModel {
        balanceContext.external.flatMap { keyValue in
            let group = keyValue.key
            let amount = keyValue.value

            guard amount > 0 else {
                return LocksSortingViewModel()
            }

            let title = group.type.lockTitle

            return createLockFieldViewModel(
                amount: amount,
                price: balanceContext.price,
                localizedTitle: title,
                amountFormatter: amountFormatter,
                priceFormatter: priceFormatter
            )
        }
    }

    private static func createReservedViewModel(
        balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        precision: Int16
    ) -> LocksSortingViewModel {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.walletBalanceReserved()
        }

        let totalHolds = balanceContext.balanceHolds.reduce(BigUInt(0)) { $0 + $1.amount }
        let totalHoldsDecimal = Decimal.fromSubstrateAmount(
            totalHolds,
            precision: precision
        ) ?? 0.0

        let totalAmount = max(balanceContext.reserved - totalHoldsDecimal, 0)

        guard totalAmount > 0 else {
            return []
        }

        return createLockFieldViewModel(
            amount: totalAmount,
            price: balanceContext.price,
            localizedTitle: title,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter
        )
    }

    private static func createLockFieldViewModel(
        amount: Decimal,
        price: Decimal,
        localizedTitle: LocalizableResource<String>,
        amountFormatter: LocalizableResource<TokenFormatter>,
        priceFormatter: LocalizableResource<TokenFormatter>
    ) -> LocksSortingViewModel {
        let totalPrice = amount * price

        let viewModel = LocalizableResource<StakingAmountViewModel> { locale in
            let formatter = priceFormatter.value(for: locale)
            let amountFormatter = amountFormatter.value(for: locale)

            let title = localizedTitle.value(for: locale)

            let priceString = totalPrice == 0.0 ? nil : formatter.stringFromDecimal(totalPrice)
            let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

            let balance = BalanceViewModel(amount: amountString, price: priceString)

            return StakingAmountViewModel(title: title, balance: balance)
        }

        return [LockSortingViewModel(value: totalPrice, viewModel: viewModel)]
    }
}
