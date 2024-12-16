import Foundation
import Operation_iOS

enum MercuryoCardResourceProviderError: Error {
    case unavailable
}

final class MercuryoCardResourceProvider {
    let chainRegistry: ChainRegistryProtocol
    let wallet: MetaAccountModel
    let chainId: ChainModel.Id

    init(
        chainRegistry: ChainRegistryProtocol,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id
    ) {
        self.chainRegistry = chainRegistry
        self.wallet = wallet
        self.chainId = chainId
    }
}

// MARK: Private

private extension MercuryoCardResourceProvider {
    func createQueryItemsWrapper() -> CompoundOperationWrapper<[URLQueryItem]> {
        let chainFetchWrapper = chainRegistry.asyncWaitChainWrapper(for: chainId)

        let queryItemsOperation = createQueryItemsOperation(
            dependingOn: chainFetchWrapper.targetOperation,
            wallet: wallet
        )

        queryItemsOperation.addDependency(chainFetchWrapper.targetOperation)

        return chainFetchWrapper.insertingTail(operation: queryItemsOperation)
    }

    func createQueryItemsOperation(
        dependingOn chainOperation: BaseOperation<ChainModel?>,
        wallet: MetaAccountModel
    ) -> BaseOperation<[URLQueryItem]> {
        ClosureOperation { [weak self] in
            guard
                let self,
                let chain = try chainOperation.extractNoCancellableResultData(),
                let utilityAsset = chain.utilityChainAsset()
            else {
                throw ChainModelFetchError.noAsset(assetId: 0)
            }

            guard
                let selectedAccount = wallet.fetch(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let refundAddress = try selectedAccount.accountId.toAddress(
                using: utilityAsset.chain.chainFormat
            )

            return createQueryItems(
                for: utilityAsset,
                refundAddress: refundAddress
            )
        }
    }

    func createQueryItems(
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
            name: "currency",
            value: "\(chainAsset.asset.symbol)"
        )
        let fiatCurrencyItem = URLQueryItem(
            name: "fiat_currency",
            value: MercuryoCardApi.fiatCurrency
        )
        let paymentMethodItem = URLQueryItem(
            name: "payment_method",
            value: MercuryoCardApi.paymentMethod
        )
        let themeItem = URLQueryItem(
            name: "theme",
            value: MercuryoCardApi.theme
        )
        let showSpendCardDetails = URLQueryItem(
            name: "show_spend_card_details",
            value: MercuryoCardApi.showSpendCardDetails
        )
        let fixPaymentMethodItem = URLQueryItem(
            name: "fix_payment_method",
            value: MercuryoCardApi.fixPaymentMethod
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
            fiatCurrencyItem,
            fixPaymentMethodItem,
            paymentMethodItem,
            hideRefundAddressItem,
            refundAddressItem
        ]
    }
}

// MARK: PayCardResourceProviding

extension MercuryoCardResourceProvider: PayCardResourceProviding {
    func loadResourceWrapper() -> CompoundOperationWrapper<PayCardHtmlResource> {
        let queryItemsWrapper = createQueryItemsWrapper()

        let mapOperation = ClosureOperation<PayCardHtmlResource> {
            let queryItems = try queryItemsWrapper.targetOperation.extractNoCancellableResultData()

            var urlComponents = URLComponents(
                url: MercuryoCardApi.widgetUrl,
                resolvingAgainstBaseURL: false
            )

            urlComponents?.queryItems = queryItems

            guard let url = urlComponents?.url else {
                throw MercuryoCardResourceProviderError.unavailable
            }

            return PayCardHtmlResource(url: url)
        }

        mapOperation.addDependency(queryItemsWrapper.targetOperation)

        return queryItemsWrapper.insertingTail(operation: mapOperation)
    }
}
