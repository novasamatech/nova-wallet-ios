import UIKit

extension AssetPriceChartViewController {
    func updateCompactView() {
        updateCompactHeader()
        updateChart()
        updateSparkline()
        updatePeriodControlIfNeeded()

        rootView.applyCompact(placeholder: dataSource.getPlaceholder())

        updateCompactLoadingState()
    }

    func updateCompactHeader() {
        rootView.titleLabel.text = dataSource.getSymbol()

        rootView.priceLabel.text = switch dataSource.getCurrentPrice() {
        case let .cached(text), let .loaded(text):
            text
        case .loading, .none:
            nil
        }

        let periodChange = dataSource.getPeriodChange()?.value

        rootView.priceChangeView.detailsLabel.text = periodChange?.percentText
        rootView.priceChangeView.detailsLabel.textColor = switch periodChange?.percentChangeType {
        case .increase:
            R.color.colorTextPositive()
        case .decrease:
            R.color.colorTextNegative()
        case nil:
            R.color.colorTextSecondary()
        }
        rootView.currentEntryDateLabel.text = periodChange?.changeDateText

        rootView.applyCompactHeader(
            showsEntryDate: isSelectingEntry && periodChange != nil,
            showsChange: periodChange != nil
        )
    }

    func updateCompactLoadingState() {
        let isChartLoading = dataSource.getChartModel()?.isLoading ?? true

        let hasNoHistory = if case .unavailable(.noHistory) = chartState {
            true
        } else {
            false
        }

        let hasNoContent = hasNoHistory || dataSource.getPlaceholder() != nil

        rootView.loadingState = isChartLoading && !hasNoContent ? .chart : .none
    }
}

// MARK: Private

private extension AssetPriceChartViewController {
    func updateSparkline() {
        guard let chartModel = dataSource.getChartModel()?.value else {
            rootView.sparklineView.clear()
            return
        }

        rootView.sparklineView.bind(
            values: chartModel.dataSet.map(\.y),
            isRising: chartModel.percentChangeType == .increase
        )
    }
}

// MARK: AssetPriceChartCompactProviderProtocol

extension AssetPriceChartViewController: AssetPriceChartCompactProviderProtocol {
    func setExpansion(isExpanded: Bool, isExpandable: Bool, animated: Bool) {
        self.isExpanded = isExpanded
        self.isExpandable = isExpandable

        rootView.applyCompactExpansion(
            isExpanded: isExpanded,
            isExpandable: isExpandable,
            animated: animated
        )

        if rootView.loadingState != .none {
            rootView.updateLoadingState()
        }
    }
}
