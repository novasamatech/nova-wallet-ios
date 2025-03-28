import Foundation
import Operation_iOS

enum MercuryoCardResourceProviderError: Error {
    case unavailable
}

final class MercuryoCardResourceProvider {
    private func createQueryItems(
        for chainAsset: ChainAsset,
        refundAddress: AccountAddress
    ) -> [URLQueryItem] {
        let widgetIdItem = URLQueryItem(
            name: "widget_id",
            value: MercuryoCardApi.widgetId
        )
        let typeItem = URLQueryItem(
            name: "type",
            value: MercuryoCardApi.type
        )
        let currencyItem = URLQueryItem(
            name: "currencies",
            value: "\(chainAsset.asset.symbol)"
        )
        let themeItem = URLQueryItem(
            name: "theme",
            value: MercuryoCardApi.theme
        )
        let showSpendCardDetails = URLQueryItem(
            name: "show_spend_card_details",
            value: MercuryoCardApi.showSpendCardDetails
        )
        let hideRefundAddressItem = URLQueryItem(
            name: "hide_refund_address",
            value: MercuryoCardApi.hideRefundAddress
        )
        let refundAddressItem = URLQueryItem(
            name: "refund_address",
            value: refundAddress
        )

        return [
            widgetIdItem,
            themeItem,
            typeItem,
            showSpendCardDetails,
            currencyItem,
            hideRefundAddressItem,
            refundAddressItem
        ]
    }
}

// MARK: PayCardResourceProviding

extension MercuryoCardResourceProvider: PayCardResourceProviding {
    func loadResource(using params: MercuryoCardParams) throws -> PayCardResource {
        let queryItems = createQueryItems(
            for: params.chainAsset,
            refundAddress: params.refundAddress
        )

        var urlComponents = URLComponents(
            url: MercuryoCardApi.widgetUrl,
            resolvingAgainstBaseURL: false
        )

        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw MercuryoCardResourceProviderError.unavailable
        }

        return PayCardResource(url: url)
    }
}
