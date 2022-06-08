import Foundation
import SoraFoundation

protocol ParaStkAccountDetailsViewModelFactoryProtocol {
    func createCollator(
        from collatorAddress: DisplayAddress,
        delegator: ParachainStaking.Delegator?,
        locale: Locale
    ) -> AccountDetailsSelectionViewModel

    func createViewModels(
        from bonds: [ParachainStaking.Bond],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>
    ) -> [LocalizableResource<SelectableViewModel<AccountDetailsSelectionViewModel>>]

    func createUnstakingViewModels(
        from scheduledRequests: [ParachainStaking.DelegatorScheduledRequest],
        identities: [AccountId: AccountIdentity]?
    ) -> [LocalizableResource<AccountDetailsSelectionViewModel>]
}

final class ParaStkAccountDetailsViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainFormat: ChainFormat
    let assetPrecision: Int16

    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainFormat: ChainFormat,
        assetPrecision: Int16
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainFormat = chainFormat
        self.assetPrecision = assetPrecision
    }

    init(chainAsset: ChainAsset) {
        let assetDisplayInfo = chainAsset.assetDisplayInfo

        balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo)
        chainFormat = chainAsset.chain.chainFormat
        assetPrecision = assetDisplayInfo.assetPrecision
    }
}

extension ParaStkAccountDetailsViewModelFactory: ParaStkAccountDetailsViewModelFactoryProtocol {
    func createCollator(
        from collatorAddress: DisplayAddress,
        delegator: ParachainStaking.Delegator?,
        locale: Locale
    ) -> AccountDetailsSelectionViewModel {
        let collatorId = try? collatorAddress.address.toAccountId()
        let addressModel = displayAddressFactory.createViewModel(from: collatorAddress)

        let details: TitleWithSubtitleViewModel?

        if let delegation = delegator?.delegations.first(where: { $0.owner == collatorId }) {
            let detailsName = R.string.localizable.commonStakedPrefix(
                preferredLanguages: locale.rLanguages
            )

            let stakedDecimal = Decimal.fromSubstrateAmount(
                delegation.amount,
                precision: assetPrecision
            ) ?? 0

            let stakedAmount = balanceViewModelFactory.amountFromValue(stakedDecimal).value(for: locale)

            details = TitleWithSubtitleViewModel(title: detailsName, subtitle: stakedAmount)
        } else {
            details = nil
        }

        return AccountDetailsSelectionViewModel(displayAddress: addressModel, details: details)
    }

    func createViewModels(
        from bonds: [ParachainStaking.Bond],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>
    ) -> [AccountDetailsPickerViewModel] {
        bonds.map { bond in
            let addressViewModel: DisplayAddressViewModel
            let address = try? bond.owner.toAddress(using: chainFormat)

            if let name = identities?[bond.owner]?.displayName {
                let displayAddress = DisplayAddress(address: address ?? "", username: name)
                addressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
            } else {
                addressViewModel = displayAddressFactory.createViewModel(from: address ?? "")
            }

            let amountDecimal = Decimal.fromSubstrateAmount(bond.amount, precision: assetPrecision) ?? 0
            let localizedAmountString = balanceViewModelFactory.amountFromValue(amountDecimal)
            let selectable = !disabled.contains(bond.owner)

            return LocalizableResource { locale in
                let detailsTitle = R.string.localizable.commonStakedPrefix(preferredLanguages: locale.rLanguages)
                let detailsSubtitle = localizedAmountString.value(for: locale)

                let details = TitleWithSubtitleViewModel(title: detailsTitle, subtitle: detailsSubtitle)

                let accountDetails = AccountDetailsSelectionViewModel(
                    displayAddress: addressViewModel,
                    details: details
                )

                return SelectableViewModel(underlyingViewModel: accountDetails, selectable: selectable)
            }
        }
    }

    func createUnstakingViewModels(
        from scheduledRequests: [ParachainStaking.DelegatorScheduledRequest],
        identities: [AccountId: AccountIdentity]?
    ) -> [LocalizableResource<AccountDetailsSelectionViewModel>] {
        scheduledRequests.map { scheduledRequest in
            let addressViewModel: DisplayAddressViewModel
            let collatorId = scheduledRequest.collatorId
            let address = try? collatorId.toAddress(using: chainFormat)

            if let name = identities?[collatorId]?.displayName {
                let displayAddress = DisplayAddress(address: address ?? "", username: name)
                addressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
            } else {
                addressViewModel = displayAddressFactory.createViewModel(from: address ?? "")
            }

            let amountDecimal = Decimal.fromSubstrateAmount(
                scheduledRequest.unstakingAmount,
                precision: assetPrecision
            ) ?? 0

            let localizedAmountString = balanceViewModelFactory.amountFromValue(amountDecimal)

            return LocalizableResource { locale in
                let detailsTitle = R.string.localizable.commonUnstakingPrefix(preferredLanguages: locale.rLanguages)
                let detailsSubtitle = localizedAmountString.value(for: locale)

                let details = TitleWithSubtitleViewModel(title: detailsTitle, subtitle: detailsSubtitle)

                let accountDetails = AccountDetailsSelectionViewModel(
                    displayAddress: addressViewModel,
                    details: details
                )

                return accountDetails
            }
        }
    }
}
