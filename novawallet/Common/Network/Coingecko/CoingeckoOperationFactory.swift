import Foundation
import RobinHood

protocol CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(
        for tokenIds: [String],
        currency: Currency,
        returnsZeroIfUnsupported: Bool
    ) -> BaseOperation<[PriceData]>
}

extension CoingeckoOperationFactoryProtocol {
    func fetchPriceOperation(for tokenIds: [String], currency: Currency) -> BaseOperation<[PriceData]> {
        fetchPriceOperation(for: tokenIds, currency: currency, returnsZeroIfUnsupported: true)
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

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<[PriceData]> { data in
            let priceData = try JSONDecoder().decode(
                [String: CoingeckoPriceData].self,
                from: data
            )

            return tokenIds.compactMap { assetId in
                guard let assetPriceData = priceData[assetId],
                      let priceData = assetPriceData.rates[currency.coingeckoId] else {
                    return returnsZeroIfUnsupported ? PriceData.zero(for: currency.id) : nil
                }

                return PriceData(
                    price: priceData.price.stringWithPointSeparator,
                    dayChange: priceData.dayChange,
                    currencyId: currency.id
                )
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
