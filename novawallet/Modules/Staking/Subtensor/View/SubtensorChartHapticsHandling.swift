import Foundation

protocol SubtensorPriceChartViewDelegate: AnyObject {
    func priceChartViewDidBeginSelection(_ chartView: SubtensorSubnetPriceChartView)
    func priceChartView(_ chartView: SubtensorSubnetPriceChartView, didSelect selection: SubtensorPriceChartSelection)
    func priceChartViewDidEndSelection(_ chartView: SubtensorSubnetPriceChartView)
}

protocol SubtensorChartHapticsHandling: SubtensorPriceChartViewDelegate {
    var seekHapticPlayer: ProgressiveHapticPlayer { get }
    var chartLongPressHapticPlayer: HapticPlayer { get }

    func didSelectChart(_ selection: SubtensorPriceChartSelection?)
}

extension SubtensorChartHapticsHandling {
    func priceChartViewDidBeginSelection(_: SubtensorSubnetPriceChartView) {
        chartLongPressHapticPlayer.play()
    }

    func priceChartView(_: SubtensorSubnetPriceChartView, didSelect selection: SubtensorPriceChartSelection) {
        seekHapticPlayer.play()
        didSelectChart(selection)
    }

    func priceChartViewDidEndSelection(_: SubtensorSubnetPriceChartView) {
        seekHapticPlayer.reset()
        didSelectChart(nil)
    }
}
