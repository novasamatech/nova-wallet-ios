import Foundation

struct AssetPriceChartWidgetViewModel {
    let title: String
    let symbol: String
    let currentPrice: LoadableViewModelState<String?>
    let periodChange: LoadableViewModelState<PricePeriodChangeViewModel>
    let chartModel: LoadableViewModelState<PriceChartViewModel>
    let periodControlModel: PriceChartPeriodControlViewModel
    let placeholder: String?
}

extension AssetPriceChartWidgetViewModel {
    func byUpdating(
        with priceUpdateViewModel: AssetPriceChartPriceUpdateViewModel
    ) -> AssetPriceChartWidgetViewModel {
        let newPeriodChange: LoadableViewModelState<PricePeriodChangeViewModel> = switch periodChange {
        case .cached: .cached(value: priceUpdateViewModel.changeViewModel)
        case .loaded: .loaded(value: priceUpdateViewModel.changeViewModel)
        case .loading: .loaded(value: priceUpdateViewModel.changeViewModel)
        }

        let newCurrentPrice: LoadableViewModelState<String?> = switch currentPrice {
        case .cached: .cached(value: priceUpdateViewModel.currentPrice)
        case .loaded: .loaded(value: priceUpdateViewModel.currentPrice)
        case .loading: .loaded(value: priceUpdateViewModel.currentPrice)
        }

        return AssetPriceChartWidgetViewModel(
            title: title,
            symbol: symbol,
            currentPrice: newCurrentPrice,
            periodChange: newPeriodChange,
            chartModel: chartModel,
            periodControlModel: periodControlModel,
            placeholder: placeholder
        )
    }
}

struct AssetPriceChartPriceUpdateViewModel {
    let currentPrice: String?
    let changeViewModel: PricePeriodChangeViewModel
}
