import Foundation

struct AssetPriceChartWidgetViewModel {
    let title: String
    let currentPrice: LoadableViewModelState<String?>
    let periodChange: LoadableViewModelState<PricePeriodChangeViewModel>
    let chartModel: LoadableViewModelState<PriceChartViewModel>
    let periodControlModel: PriceChartPeriodControlViewModel
}

extension AssetPriceChartWidgetViewModel {
    func byUpdatingPeriodChange(_ newValue: PricePeriodChangeViewModel) -> AssetPriceChartWidgetViewModel {
        let newPeriodChange: LoadableViewModelState<PricePeriodChangeViewModel> = switch periodChange {
        case .cached: .cached(value: newValue)
        case .loaded: .loaded(value: newValue)
        case .loading: .loaded(value: newValue)
        }

        return AssetPriceChartWidgetViewModel(
            title: title,
            currentPrice: currentPrice,
            periodChange: newPeriodChange,
            chartModel: chartModel,
            periodControlModel: periodControlModel
        )
    }
}
