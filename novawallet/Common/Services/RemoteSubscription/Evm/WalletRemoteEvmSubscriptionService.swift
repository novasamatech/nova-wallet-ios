import Foundation

protocol WalletRemoteEvmSubscriptionServiceProtocol {
    func attachERC20Balance(
        for accountId: AccountId,
        chain: ChainModel,
        transactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol?,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachERC20Balance(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

final class WalletRemoteEvmSubscriptionService: EvmRemoteSubscriptionService,
    WalletRemoteEvmSubscriptionServiceProtocol {
    private func createERC20CacheKey(for chainId: ChainModel.Id, accountId: AccountId) -> String {
        "erc20" + "-" + chainId + "-" + accountId.toHex()
    }

    func attachERC20Balance(
        for accountId: AccountId,
        chain: ChainModel,
        transactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol?,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        let cacheKey = createERC20CacheKey(for: chain.chainId, accountId: accountId)

        guard let holder = try? accountId.toAddress(using: chain.chainFormat) else {
            let error = AccountAddressConversionError.invalidEthereumAddress
            dispatchInQueueWhenPossible(queue) { closure?(.failure(error)) }
            return nil
        }

        let assetContracts: [EvmAssetContractId] = chain.assets.compactMap { asset in
            guard let contractAddress = asset.evmContractAddress else {
                return nil
            }

            return EvmAssetContractId(
                chainAssetId: .init(chainId: chain.chainId, assetId: asset.assetId),
                contract: contractAddress
            )
        }

        guard !assetContracts.isEmpty else {
            dispatchInQueueWhenPossible(queue) { closure?(.success(())) }
            return nil
        }

        do {
            let transactionHistoryUpdater = transactionHistoryUpdaterFactory?.createTransactionHistoryUpdater(
                for: accountId,
                assetContracts: Set(assetContracts)
            )

            let request = ERC20BalanceSubscriptionRequest(
                holder: holder,
                contracts: Set(assetContracts),
                transactionHistoryUpdater: transactionHistoryUpdater
            )

            return try attachToSubscription(
                on: chain.chainId,
                request: .erc20Balace(request),
                cacheKey: cacheKey,
                queue: queue,
                closure: closure
            )
        } catch {
            dispatchInQueueWhenPossible(queue) { closure?(.failure(error)) }
            return nil
        }
    }

    func detachERC20Balance(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        let cacheKey = createERC20CacheKey(for: chainId, accountId: accountId)

        detachFromSubscription(cacheKey, subscriptionId: subscriptionId, queue: queue, closure: closure)
    }
}
