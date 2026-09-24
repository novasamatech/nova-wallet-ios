import Foundation
import Operation_iOS

protocol CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for tokenIds: [String],
        currency: Currency,
        returnsZeroIfUnsupported: Bool
    ) -> BaseOperation<[PriceData]>

    func fetchPriceHistory(
        for tokenId: String,
        currency: Currency,
        period: PriceHistoryPeriod
    ) -> BaseOperation<PriceHistory>
}

extension CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for tokenIds: [String],
        currency: Currency
    ) -> BaseOperation<[PriceData]> {
        fetchPriceOperation(
            for: tokenIds,
            currency: currency,
            returnsZeroIfUnsupported: true
        )
    }
}

final class CoingeckoOperationFactory {
    private let crossRateUpdater: AnalyticsCrossRateUpdating?

    init(crossRateUpdater: AnalyticsCrossRateUpdating? = AnalyticsCrossRateFactory.createUpdater()) {
        self.crossRateUpdater = crossRateUpdater
    }

    private func buildURLForAssets(
        _ tokenIds: [String],
        method: String,
        currencies: [String] = ["usd"]
    ) -> URL? {
        guard var components = URLComponents(
            url: PriceAPI.baseURL.appendingPathComponent(method),
            resolvingAgainstBaseURL: false
        ) else { return nil }

        let tokenIDParam = tokenIds.joined(separator: ",")
        let currencyParam = currencies.joined(separator: ",")

        components.queryItems = [
            URLQueryItem(name: "ids", value: tokenIDParam),
            URLQueryItem(name: "vs_currencies", value: currencyParam),
            URLQueryItem(name: "include_24hr_change", value: "true")
        ]

        return components.url
    }

    private func buildURLForPriceHistory(
        tokenId: String,
        queryItems: [URLQueryItem]
    ) -> URL? {
        let method = PriceAPI.priceHistory(for: tokenId)

        guard var components = URLComponents(
            url: PriceAPI.proxyBaseURL.appendingPathComponent(method),
            resolvingAgainstBaseURL: false
        ) else { return nil }

        components.queryItems = queryItems

        return components.url
    }

    private func buildURLForPriceHistoryPeriod(
        tokenId: String,
        currency: String,
        period: PriceAPI.Period
    ) -> URL? {
        let queryItems = [
            URLQueryItem(name: "vs_currency", value: currency),
            URLQueryItem(name: "days", value: period.rawValue)
        ]

        return buildURLForPriceHistory(
            tokenId: tokenId,
            queryItems: queryItems
        )
    }

    private func buildOperation<T>(for url: URL, processingBlock: @escaping (Data) throws -> T) -> BaseOperation<T> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<T>(processingBlock: processingBlock)

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    private func decodeToPriceHistory(
        _ data: Data,
        _ currency: Currency
    ) throws -> PriceHistory {
        let priceHistory = try JSONDecoder().decode(CoingeckPriceHistoryData.self, from: data)

        let historyItems = priceHistory.prices.map { item in
            PriceHistoryItem(startedAt: UInt64(item.time.timeInterval), value: item.value)
        }

        return PriceHistory(currencyId: currency.id, items: historyItems)
    }
}

// MARK: - Private

private extension CoingeckoOperationFactory {
    static func currencyCodes(for currency: Currency) -> [String] {
        let usdCode = Currency.usd.coingeckoId

        guard currency.coingeckoId != usdCode else {
            return [usdCode]
        }

        return [currency.coingeckoId, usdCode]
    }

    static func crossRate(
        from priceData: [String: CoingeckoPriceData],
        for currency: Currency
    ) -> Decimal? {
        let usdCode = Currency.usd.coingeckoId

        guard currency.coingeckoId != usdCode else {
            return 1
        }

        for rates in priceData.values.map(\.rates) {
            guard
                let usdPrice = rates[usdCode]?.price,
                let displayPrice = rates[currency.coingeckoId]?.price,
                usdPrice > 0,
                displayPrice > 0
            else {
                continue
            }

            return usdPrice / displayPrice
        }

        return nil
    }
}

extension CoingeckoOperationFactory: CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for tokenIds: [String],
        currency: Currency,
        returnsZeroIfUnsupported: Bool
    ) -> BaseOperation<[PriceData]> {
        guard let url = buildURLForAssets(
            tokenIds,
            method: PriceAPI.price,
            currencies: Self.currencyCodes(for: currency)
        ) else {
            return BaseOperation.createWithError(NetworkBaseError.invalidUrl)
        }

        return buildOperation(for: url) { [weak crossRateUpdater] data in
            let priceData = try JSONDecoder().decode(
                [String: CoingeckoPriceData].self,
                from: data
            )

            if let usdPerUnit = Self.crossRate(from: priceData, for: currency) {
                crossRateUpdater?.save(usdPerUnit: usdPerUnit, for: currency)
            }

            return tokenIds.compactMap { assetId in
                let identifier = PriceData.createIdentifier(for: assetId, currencyId: currency.id)

                guard let assetPriceData = priceData[assetId],
                      let priceData = assetPriceData.rates[currency.coingeckoId] else {
                    return returnsZeroIfUnsupported ? PriceData.zero(for: identifier, currencyId: currency.id) : nil
                }

                return PriceData(
                    identifier: identifier,
                    price: priceData.price.stringWithPointSeparator,
                    dayChange: priceData.dayChange,
                    currencyId: currency.id
                )
            }
        }
    }

    func fetchPriceHistory(
        for tokenId: String,
        currency: Currency,
        period: PriceHistoryPeriod
    ) -> BaseOperation<PriceHistory> {
        guard
            let url = buildURLForPriceHistoryPeriod(
                tokenId: tokenId,
                currency: currency.coingeckoId,
                period: PriceAPI.Period(from: period)
            ) else {
            return BaseOperation.createWithError(NetworkBaseError.invalidUrl)
        }

        return buildOperation(for: url) { [weak self] data in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            return try decodeToPriceHistory(data, currency)
        }
    }
}
