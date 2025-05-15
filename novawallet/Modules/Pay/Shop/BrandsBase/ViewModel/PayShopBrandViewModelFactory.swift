import Foundation
import Foundation_iOS

protocol PayShopBrandViewModelFactoryProtocol {
    func createViewModel(
        fromBrand model: RaiseBrandRemote,
        locale: Locale
    ) -> PayShopBrandViewModel
}

final class PayShopBrandViewModelFactory {
    let comissionFormatter: LocalizableResource<NumberFormatter>

    init(
        comissionFormatter: LocalizableResource<NumberFormatter> = NumberFormatter.shopRaise.localizableResource()
    ) {
        self.comissionFormatter = comissionFormatter
    }
}

extension PayShopBrandViewModelFactory: PayShopBrandViewModelFactoryProtocol {
    func createViewModel(
        fromBrand model: RaiseBrandRemote,
        locale: Locale
    ) -> PayShopBrandViewModel {
        let iconViewModel = model.attributes.iconUrl.flatMap { iconUrl in
            URL(string: iconUrl).map { RemoteImageViewModel(url: $0) }
        }

        let commission = model.attributes.comissionInPercentFraction
        let commissionNumber = NSNumber(value: commission)
        let commissionString = commission > 0 ? comissionFormatter.value(for: locale).string(from: commissionNumber) : nil

        return PayShopBrandViewModel(
            identifier: model.identifier,
            iconViewModel: iconViewModel,
            name: model.attributes.name,
            commission: commissionString
        )
    }
}
