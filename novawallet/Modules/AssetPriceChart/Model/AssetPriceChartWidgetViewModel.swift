import Foundation

struct AssetPriceChartWidgetViewModel {
    let title: String
    let currentPrice: LoadableViewModelState<String?>
    let periodChange: LoadableViewModelState<PricePeriodChangeViewModel>
    let chartModel: LoadableViewModelState<PriceChartViewModel>
    let periodControlModel: PriceChartPeriodControlViewModel
}
