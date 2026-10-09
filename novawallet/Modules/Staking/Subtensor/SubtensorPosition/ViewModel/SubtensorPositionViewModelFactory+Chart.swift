import Foundation
import Foundation_iOS

extension SubtensorPositionViewModelFactory {
    func createPriceWidget(for state: SubtensorPositionState, locale: Locale) -> SubtensorPriceWidgetViewModel? {
        createPriceWidgetParams(for: state, locale: locale).map { params in
            priceWidgetFactory.createWidget(for: params, locale: locale)
        }
    }

    func createPriceHeader(for state: SubtensorPositionState, locale: Locale) -> SubtensorSubnetPriceHeaderViewModel? {
        createPriceWidgetParams(for: state, locale: locale).map { params in
            priceWidgetFactory.createHeader(for: params, locale: locale)
        }
    }
}

private extension SubtensorPositionViewModelFactory {
    func createPriceWidgetParams(
        for state: SubtensorPositionState,
        locale: Locale
    ) -> SubtensorPriceWidgetParams? {
        guard !state.isRoot, state.hasResolvedHistory else {
            return nil
        }

        let subnet = state.catalogue?.subnet(for: state.netuid)

        let caption = priceWidgetFactory.createCaption(
            subnetTitle: SubtensorSubnetNaming.titleWithSymbol(for: state.netuid, in: state.catalogue, locale: locale),
            stamps: subnet?.stamps ?? [],
            now: Date(),
            locale: locale
        )

        return SubtensorPriceWidgetParams(
            caption: caption,
            spotPrice: subnet?.taoPerAlpha.decimal(assetInfo: chainAsset.assetDisplayInfo),
            history: state.history,
            period: state.period,
            isFiat: false,
            taoPrice: nil,
            currencyId: nil,
            currency: nil,
            selectedPoint: state.chartPoint
        )
    }
}
