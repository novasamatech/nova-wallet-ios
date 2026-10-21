import Foundation
import Foundation_iOS

extension SubtensorUnstakeSetupViewModelFactory {
    func createPickerViewModels(
        for positions: [SubtensorPosition],
        names: [AccountId: String],
        disabled: Set<AccountId>,
        netuid: UInt16,
        catalogue: SubtensorSubnetCatalogue?
    ) -> [AccountDetailsPickerViewModel] {
        let displayInfo = inputDisplayInfo(for: netuid, catalogue: catalogue)
        let tokenFormatter = AssetBalanceFormatterFactory().createTokenFormatter(for: displayInfo)

        return positions.map { position in
            let address = (try? position.hotkey.toAddress(using: chainAsset.chain.chainFormat)) ?? ""
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

    func createAllValidatorsAction() -> LocalizableResource<IconWithTitleViewModel> {
        LocalizableResource { locale in
            IconWithTitleViewModel(
                icon: R.image.iconValidators()?.tinted(with: R.color.colorIconAccent()!),
                title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValidatorAll()
            )
        }
    }

    func createPickerTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingCommonValidator()
        }
    }
}
