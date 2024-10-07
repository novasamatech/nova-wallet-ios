import Foundation
import Operation_iOS

struct MercuryoCardParams {
    let chainAsset: ChainAsset
    let refundAccountId: AccountId
}

enum MercuryoCardApi {
    static let widgetUrl = URL(string: "https://exchange.mercuryo.io")!
    static let widgetId = "4ce98182-ed76-4933-ba1b-b85e4a51d75a" // TODO: Change for production
    static let cardsEndpoint = "https://api.mercuryo.io/v1.6/cards"
}

final class MercuryoCardHookFactory {
    let chainRegistry: ChainRegistryProtocol
    let wallet: MetaAccountModel
    let chainId: ChainModel.Id
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.wallet = wallet
        self.chainId = chainId
        self.logger = logger
    }

    private func createHooksOperation(
        dependingOn chainOperation: BaseOperation<ChainModel?>,
        wallet: MetaAccountModel,
        delegate: PayCardHookDelegate
    ) -> BaseOperation<[PayCardHook]> {
        ClosureOperation {
            guard
                let chain = try chainOperation.extractNoCancellableResultData(),
                let utilityAsset = chain.utilityChainAsset() else {
                throw ChainModelFetchError.noAsset(assetId: 0)
            }

            guard
                let selectedAccount = wallet.fetch(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            let params = MercuryoCardParams(
                chainAsset: utilityAsset,
                refundAccountId: selectedAccount.accountId
            )

            let responseHook = self.createCardsResponseInterceptingHook(for: delegate)
            let widgetHooks = try self.createWidgetHooks(for: delegate, params: params)

            return widgetHooks + [responseHook]
        }
    }
}

extension MercuryoCardHookFactory: PayCardHookFactoryProtocol {
    func createHooks(for delegate: PayCardHookDelegate) -> CompoundOperationWrapper<[PayCardHook]> {
        let fetchChainWrapper = chainRegistry.asyncWaitChainWrapper(for: chainId)

        let hooksOperation = createHooksOperation(
            dependingOn: fetchChainWrapper.targetOperation,
            wallet: wallet,
            delegate: delegate
        )

        hooksOperation.addDependency(fetchChainWrapper.targetOperation)

        return fetchChainWrapper.insertingTail(operation: hooksOperation)
    }
}
