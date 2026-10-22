import Foundation
import Foundation_iOS

struct SubtensorSubnetFiltersViewModelFactory {
    let chainAsset: ChainAsset

    private let compactTokenFormatter: LocalizableResource<TokenFormatter>

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
        compactTokenFormatter = AssetBalanceFormatterFactory().createCompactTokenFormatter(
            for: chainAsset.assetDisplayInfo
        )
    }

    func createViewModel(
        filters: SubtensorSubnetFilters,
        count: Int?,
        locale: Locale
    ) -> SubtensorSubnetFiltersViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let thresholdDecimal = SubtensorSubnetListBuilder.thinPoolThreshold.decimal(
            assetInfo: chainAsset.assetDisplayInfo
        )

        let threshold = compactTokenFormatter.value(for: locale).stringFromDecimal(thresholdDecimal) ??
            strings.stakingSubtensorUiValueUnknown()

        return SubtensorSubnetFiltersViewModel(
            title: strings.walletFiltersTitle(),
            thinPoolsTitle: strings.stakingSubtensorUiPickerHideThin(),
            thinPoolsDetails: strings.stakingSubtensorUiPickerHideThinFormat(threshold),
            filters: filters,
            actionTitle: count.map { strings.stakingSubtensorUiPickerShowCount(format: $0) } ??
                strings.stakingSubtensorUiPickerShow(),
            isLoading: count == nil
        )
    }
}
