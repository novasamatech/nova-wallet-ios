import Foundation
import Foundation_iOS

struct YieldBoostCollatorSelection {
    let apr: Decimal?
    let collatorId: AccountId
}

protocol YieldBoostCollatorSelectionFactoryProtocol {
    func createViewModels(
        from collators: [YieldBoostCollatorSelection],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>,
        yieldBoostTasks: [ParaStkYieldBoostState.Task]
    ) -> [AccountDetailsPickerViewModel]
}

final class YieldBoostCollatorSelectionFactory: YieldBoostCollatorSelectionFactoryProtocol {
    let chainFormat: ChainFormat
    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()
    private lazy var formatter = NumberFormatter.percentAPR.localizableResource()

    init(chainFormat: ChainFormat) {
        self.chainFormat = chainFormat
    }

    func createViewModels(
        from collators: [YieldBoostCollatorSelection],
        identities: [AccountId: AccountIdentity]?,
        disabled: Set<AccountId>,
        yieldBoostTasks: [ParaStkYieldBoostState.Task]
    ) -> [AccountDetailsPickerViewModel] {
        collators.map { collator in
            let addressViewModel: DisplayAddressViewModel
            let address = try? collator.collatorId.toAddress(using: chainFormat)

            if let name = identities?[collator.collatorId]?.displayName {
                let displayAddress = DisplayAddress(address: address ?? "", username: name)
                addressViewModel = displayAddressFactory.createViewModel(from: displayAddress)
            } else {
                addressViewModel = displayAddressFactory.createViewModel(from: address ?? "")
            }

            let localizedAprString = LocalizableResource<String> { [weak self] locale in
                if let apr = collator.apr {
                    return self?.formatter.value(for: locale).stringFromDecimal(apr) ?? ""
                } else {
                    return R.string(preferredLanguages: locale.rLanguages).localizable.commonNotAvailable()
                }
            }

            let selectable = !disabled.contains(collator.collatorId)

            let isYieldBoosted = yieldBoostTasks.contains { $0.collatorId == collator.collatorId }

            return LocalizableResource { locale in
                let detailsTitle = localizedAprString.value(for: locale)
                let detailsSubtitle = isYieldBoosted ? R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonYieldBoosted() : ""

                let details = TitleWithSubtitleViewModel(title: detailsTitle, subtitle: detailsSubtitle)

                let accountDetails = AccountDetailsSelectionViewModel(
                    displayAddress: addressViewModel,
                    details: details
                )

                return SelectableViewModel(underlyingViewModel: accountDetails, selectable: selectable)
            }
        }
    }
}
