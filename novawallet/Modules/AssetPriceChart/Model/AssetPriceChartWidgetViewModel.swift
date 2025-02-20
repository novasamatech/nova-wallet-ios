import Foundation

struct AssetPriceChartWidgetViewModel {
    let title: String
    let currentPrice: String?
    let periodChange: PricePeriodChangeViewModel
    let chartModel: PriceChartViewModel
    let periodControlModel: PriceChartPeriodControlViewModel
}
