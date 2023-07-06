import Foundation
import RobinHood

protocol CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for tokenIds: [String],
        currency: Currency,
        returnsZeroIfUnsupported: Bool
    ) -> BaseOperation<[PriceData]>

    func fetchPriceHistory(
        for tokenId: String,
        currency: Currency,
        startDate: Date,
        endDate: Date
    ) -> BaseOperation<PriceHistory>
}

extension CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(for tokenIds: [String], currency: Currency) -> BaseOperation<[PriceData]> {
        fetchPriceOperation(for: tokenIds, currency: currency, returnsZeroIfUnsupported: true)
    }

    func fetchPriceHistory(for tokenId: String, currency: Currency) -> BaseOperation<PriceHistory> {
        fetchPriceHistory(
            for: tokenId,
            currency: currency,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date()
        )
    }
}

final class CoingeckoOperationFactory {
    private func buildURLForAssets(
        _ tokenIds: [String],
        method: String,
        currencies: [String] = ["usd"]
    ) -> URL? {
        guard var components = URLComponents(
            url: CoingeckoAPI.baseURL.appendingPathComponent(method),
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
        currency: String,
        startDate: Date,
        endDate: Date
    ) -> URL? {
        let method = CoingeckoAPI.priceHistory(for: tokenId)

        guard var components = URLComponents(
            url: CoingeckoAPI.baseURL.appendingPathComponent(method),
            resolvingAgainstBaseURL: false
        ) else { return nil }

        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: currency),
            URLQueryItem(name: "from", value: "\(UInt64(startDate.timeIntervalSince1970))"),
            URLQueryItem(name: "to", value: "\(UInt64(endDate.timeIntervalSince1970))")
        ]

        return components.url
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
}

extension CoingeckoOperationFactory: CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for tokenIds: [String],
        currency: Currency,
        returnsZeroIfUnsupported: Bool
    ) -> BaseOperation<[PriceData]> {
        guard let url = buildURLForAssets(
            tokenIds,
            method: CoingeckoAPI.price,
            currencies: [currency.coingeckoId]
        ) else {
            return BaseOperation.createWithError(NetworkBaseError.invalidUrl)
        }

        return buildOperation(for: url) { data in
            let priceData = try JSONDecoder().decode(
                [String: CoingeckoPriceData].self,
                from: data
            )

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
        startDate: Date,
        endDate: Date
    ) -> BaseOperation<PriceHistory> {
        guard
            let url = buildURLForPriceHistory(
                tokenId: tokenId,
                currency: currency.coingeckoId,
                startDate: startDate,
                endDate: endDate
            ) else {
            return BaseOperation.createWithError(NetworkBaseError.invalidUrl)
        }

        return buildOperation(for: url) { data in
            let priceHistory = try JSONDecoder().decode(CoingeckPriceHistoryData.self, from: data)

            let historyItems = priceHistory.prices.map { item in
                PriceHistoryItem(startedAt: UInt64(item.time.timeInterval), value: item.value)
            }

            return PriceHistory(currencyId: currency.id, items: historyItems)
        }
    }
}
