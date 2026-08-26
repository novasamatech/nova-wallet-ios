import Foundation
import Foundation_iOS

protocol CollatorStakingAccountViewModelFactoryProtocol {
    /// `assetDisplayInfo` overrides the chain asset for lanes whose amounts are not denominated in
    /// the utility token, such as the Subtensor subnet lane where a position is held in alpha
    func createCollator(
        from collatorAddress: DisplayAddress,
        stakedAmount: Balance?,
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        locale: Locale
    ) -> AccountDetailsSelectionViewModel

    func createViewModels(
        from stakeDistribution: [CollatorStakingAccountViewModelFactory.StakedCollator],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>,
        assetDisplayInfo: AssetBalanceDisplayInfo?
    ) -> [LocalizableResource<SelectableViewModel<AccountDetailsSelectionViewModel>>]

    func createUnstakingViewModels(
        from scheduledRequests: [CollatorStakingAccountViewModelFactory.StakedCollator],
        identities: [AccountId: AccountIdentity]?
    ) -> [LocalizableResource<AccountDetailsSelectionViewModel>]
}

extension CollatorStakingAccountViewModelFactoryProtocol {
    func createCollator(
        from collatorAddress: DisplayAddress,
        stakedAmount: Balance?,
        locale: Locale
    ) -> AccountDetailsSelectionViewModel {
        createCollator(
            from: collatorAddress,
            stakedAmount: stakedAmount,
            assetDisplayInfo: nil,
            locale: locale
        )
    }

    func createViewModels(
        from stakeDistribution: [CollatorStakingAccountViewModelFactory.StakedCollator],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>
    ) -> [LocalizableResource<SelectableViewModel<AccountDetailsSelectionViewModel>>] {
        createViewModels(
            from: stakeDistribution,
            identities: identities,
            disabled: disabled,
            assetDisplayInfo: nil
        )
    }
}

final class CollatorStakingAccountViewModelFactory {
    let formatter: LocalizableResource<TokenFormatter>
    let chainAsset: ChainAsset
    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()
    private let formatterFactory = AssetBalanceFormatterFactory()

    var chainFormat: ChainFormat {
        chainAsset.chain.chainFormat
    }

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
        formatter = AssetBalanceFormatterFactory().createTokenFormatter(for: chainAsset.assetDisplayInfo)
    }

    private func resolveDisplayInfo(_ assetDisplayInfo: AssetBalanceDisplayInfo?) -> AssetBalanceDisplayInfo {
        assetDisplayInfo ?? chainAsset.assetDisplayInfo
    }

    private func resolveFormatter(
        for assetDisplayInfo: AssetBalanceDisplayInfo?
    ) -> LocalizableResource<TokenFormatter> {
        guard let assetDisplayInfo, assetDisplayInfo != chainAsset.assetDisplayInfo else {
            return formatter
        }

        return formatterFactory.createTokenFormatter(for: assetDisplayInfo)
    }
}

extension CollatorStakingAccountViewModelFactory: CollatorStakingAccountViewModelFactoryProtocol {
    func createCollator(
        from collatorAddress: DisplayAddress,
        stakedAmount: Balance?,
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        locale: Locale
    ) -> AccountDetailsSelectionViewModel {
        let addressModel = displayAddressFactory.createViewModel(from: collatorAddress)

        let details: TitleWithSubtitleViewModel?

        if let stakedAmount {
            let detailsName = R.string(preferredLanguages: locale.rLanguages).localizable.commonStakedPrefix()

            let stakedDecimal = stakedAmount.decimal(assetInfo: resolveDisplayInfo(assetDisplayInfo))

            let amountFormatter = resolveFormatter(for: assetDisplayInfo)

            let stakedAmount = amountFormatter.value(for: locale).stringFromDecimal(stakedDecimal) ?? ""

            details = TitleWithSubtitleViewModel(title: detailsName, subtitle: stakedAmount)
        } else {
            details = nil
        }

        return AccountDetailsSelectionViewModel(displayAddress: addressModel, details: details)
    }

    func createViewModels(
        from stakeDistribution: [StakedCollator],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>,
        assetDisplayInfo: AssetBalanceDisplayInfo?
    ) -> [LocalizableResource<SelectableViewModel<AccountDetailsSelectionViewModel>>] {
        let displayInfo = resolveDisplayInfo(assetDisplayInfo)
        let amountFormatter = resolveFormatter(for: assetDisplayInfo)

        return stakeDistribution.map { stake in
            let addressViewModel: DisplayAddressViewModel
            let address = try? stake.collator.toAddress(using: chainFormat)

            if let name = identities?[stake.collator]?.displayName {
                let displayAddress = DisplayAddress(address: address ?? "", username: name)
                addressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
            } else {
                addressViewModel = displayAddressFactory.createViewModel(from: address ?? "")
            }

            let amountDecimal = stake.amount.decimal(assetInfo: displayInfo)

            let localizedAmountString = LocalizableResource<String> { locale in
                amountFormatter.value(for: locale).stringFromDecimal(amountDecimal) ?? ""
            }

            let selectable = !disabled.contains(stake.collator)

            return LocalizableResource { locale in
                let detailsTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonStakedPrefix()
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
        from scheduledRequests: [StakedCollator],
        identities: [AccountId: AccountIdentity]?
    ) -> [LocalizableResource<AccountDetailsSelectionViewModel>] {
        scheduledRequests.map { scheduledRequest in
            let addressViewModel: DisplayAddressViewModel
            let collatorId = scheduledRequest.collator
            let address = try? collatorId.toAddress(using: chainFormat)

            if let name = identities?[collatorId]?.displayName {
                let displayAddress = DisplayAddress(address: address ?? "", username: name)
                addressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
            } else {
                addressViewModel = displayAddressFactory.createViewModel(from: address ?? "")
            }

            let amountDecimal = scheduledRequest.amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

            let amountFormatter = formatter

            let localizedAmountString = LocalizableResource<String> { locale in
                amountFormatter.value(for: locale).stringFromDecimal(amountDecimal) ?? ""
            }

            return LocalizableResource { locale in
                let detailsTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonUnstakingPrefix()
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

extension CollatorStakingAccountViewModelFactory {
    struct StakedCollator {
        let collator: AccountId
        let amount: Balance
    }
}
