import Foundation
import SoraFoundation

protocol MythosStkAccountDetailsViewModelFactoryProtocol {
    func createCollator(
        from collatorAddress: DisplayAddress,
        stakedAmount: Balance?,
        locale: Locale
    ) -> AccountDetailsSelectionViewModel
}

final class MythosStkAccountDetailsViewModelFactory {
    let formatter: LocalizableResource<TokenFormatter>
    let chainAsset: ChainAsset
    private lazy var displayAddressFactory = DisplayAddressViewModelFactory()

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
        formatter = AssetBalanceFormatterFactory().createTokenFormatter(for: chainAsset.assetDisplayInfo)
    }
}

extension MythosStkAccountDetailsViewModelFactory: MythosStkAccountDetailsViewModelFactoryProtocol {
    func createCollator(
        from collatorAddress: DisplayAddress,
        stakedAmount: Balance?,
        locale: Locale
    ) -> AccountDetailsSelectionViewModel {
        let collatorId = try? collatorAddress.address.toAccountId()
        let addressModel = displayAddressFactory.createViewModel(from: collatorAddress)

        let details: TitleWithSubtitleViewModel?
        
        if let stakedAmount {
            let detailsName = R.string.localizable.commonStakedPrefix(
                preferredLanguages: locale.rLanguages
            )

            let stakedDecimal = stakedAmount.decimal(assetInfo: chainAsset.assetDisplayInfo)

            let stakedAmount = formatter.value(for: locale).stringFromDecimal(stakedDecimal) ?? ""

            details = TitleWithSubtitleViewModel(title: detailsName, subtitle: stakedAmount)
        } else {
            details = nil
        }

        return AccountDetailsSelectionViewModel(displayAddress: addressModel, details: details)
    }
}
