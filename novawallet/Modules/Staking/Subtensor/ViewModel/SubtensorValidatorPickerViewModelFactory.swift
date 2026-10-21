import Foundation
import Foundation_iOS

struct SubtensorValidatorPickerViewModelFactory {
    let chainFormat: ChainFormat
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory()

    func createViewModels(
        for positions: [SubtensorPosition],
        names: [AccountId: String],
        disabled: Set<AccountId>,
        displayInfo: AssetBalanceDisplayInfo
    ) -> [AccountDetailsPickerViewModel] {
        let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: displayInfo)

        return positions.map { position in
            let address = (try? position.hotkey.toAddress(using: chainFormat)) ?? ""
            let addressViewModel = displayAddressFactory.createViewModel(
                from: DisplayAddress(address: address, username: names[position.hotkey] ?? "")
            )
            let amount = position.stakeAlpha.decimal(assetInfo: displayInfo)
            let isSelectable = !disabled.contains(position.hotkey)

            return LocalizableResource { locale in
                let staked = tokenFormatter.value(for: locale).stringFromDecimal(amount) ?? ""

                let details = TitleWithSubtitleViewModel(
                    title: R.string(preferredLanguages: locale.rLanguages).localizable.commonStakedPrefix(),
                    subtitle: SubtensorSubnetNaming.isolatedLeftToRight(staked)
                )

                return SelectableViewModel(
                    underlyingViewModel: AccountDetailsSelectionViewModel(
                        displayAddress: addressViewModel,
                        details: details
                    ),
                    selectable: isSelectable
                )
            }
        }
    }

    func createTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingCommonValidator()
        }
    }

    func createAllValidatorsAction() -> LocalizableResource<IconWithTitleViewModel> {
        LocalizableResource { locale in
            IconWithTitleViewModel(
                icon: nil,
                title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValidatorAll()
            )
        }
    }

    func createNewValidatorAction() -> LocalizableResource<IconWithTitleViewModel> {
        LocalizableResource { locale in
            IconWithTitleViewModel(
                icon: R.image.iconBlueAdd(),
                title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValidatorNew()
            )
        }
    }
}
