import Foundation
import Foundation_iOS

protocol PayShopViewModelFactoryProtocol {
    func createAvailabilityViewModel(
        from brands: [RaiseBrandRemote],
        locale: Locale
    ) -> PayShopAvailabilityViewModel
}

final class PayShopViewModelFactory {
    let percentFormatter: LocalizableResource<NumberFormatter>

    init(
        percentFormatter: LocalizableResource<NumberFormatter> = NumberFormatter.shopRaise.localizableResource()
    ) {
        self.percentFormatter = percentFormatter
    }
}

extension PayShopViewModelFactory: PayShopViewModelFactoryProtocol {
    func createAvailabilityViewModel(
        from brands: [RaiseBrandRemote],
        locale: Locale
    ) -> PayShopAvailabilityViewModel {
        guard !brands.isEmpty else {
            return .available(.loading)
        }

        let maxCashback = brands
            .max { $0.attributes.commissionRate < $1.attributes.commissionRate }?
            .attributes.comissionInPercentFraction

        let value = maxCashback.map { NSNumber(value: $0) }

        guard let maxCashbackString = value.flatMap({ percentFormatter.value(for: locale).string(from: $0) }) else {
            return .available(.loading)
        }

        return .available(.loaded(viewModel: maxCashbackString))
    }
}
