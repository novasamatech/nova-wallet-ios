import Foundation

extension SubtensorPositionViewModelFactory {
    func createPriceWidget(for state: SubtensorPositionState, locale: Locale) -> SubtensorPriceWidgetViewModel? {
        createPriceWidgetParams(for: state).map { params in
            priceWidgetFactory.createWidget(
                for: params,
                header: createPriceHeaderParams(for: state, locale: locale),
                locale: locale
            )
        }
    }

    func createPriceHeader(for state: SubtensorPositionState, locale: Locale) -> SubtensorSubnetPriceHeaderViewModel? {
        createPriceWidgetParams(for: state).map { params in
            priceWidgetFactory.createHeader(
                createPriceHeaderParams(for: state, locale: locale),
                for: params,
                locale: locale
            )
        }
    }
}

private extension SubtensorPositionViewModelFactory {
    func createPriceWidgetParams(for state: SubtensorPositionState) -> SubtensorPriceWidgetParams? {
        guard !state.isRoot, state.hasResolvedHistory else {
            return nil
        }

        return SubtensorPriceWidgetParams(
            history: state.history,
            period: state.period,
            isFiat: false,
            taoPrice: nil,
            currencyId: nil,
            chartEndDate: state.chartEndDate
        )
    }

    func createPriceHeaderParams(for state: SubtensorPositionState, locale: Locale) -> SubtensorPriceHeaderParams {
        let subnet = state.catalogue?.subnet(for: state.netuid)

        let caption = priceWidgetFactory.createCaption(
            subnetTitle: SubtensorSubnetNaming.titleWithSymbol(for: state.netuid, in: state.catalogue, locale: locale),
            stamps: subnet?.stamps ?? [],
            now: Date(),
            locale: locale
        )

        return SubtensorPriceHeaderParams(
            caption: caption,
            spotPrice: subnet?.taoPerAlpha.decimal(assetInfo: chainAsset.assetDisplayInfo),
            currency: nil,
            selection: state.chartSelection
        )
    }
}
