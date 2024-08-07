import Foundation

extension BalanceRemoteSubscriptionService: BalanceRemoteSubscriptionServiceProtocol {
    private func createCacheKey(from accountId: AccountId, chainId: ChainModel.Id) -> String {
        "balances-\(accountId.toHex())-\(chainId)"
    }

    private func createCacheKey(from accountId: AccountId, chainAssetId: ChainAssetId) -> String {
        "balances-\(accountId.toHex())-\(chainAssetId.chainId)-\(chainAssetId.assetId)"
    }

    func attachToBalances(
        for accountId: AccountId,
        chain: ChainModel,
        onlyFor assetIds: Set<AssetModel.Id>?,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        guard
            let transactionSubscription = try? transactionSubscriptionFactory.createTransactionSubscription(
                for: accountId,
                chain: chain
            ) else {
            logger.error("Can't create transaction subscription")
            return nil
        }

        let subscriptionSettingsList = prepareSubscriptionRequests(
            from: accountId,
            chain: chain,
            onlyFor: assetIds,
            transactionSubscription: transactionSubscription
        )

        guard !subscriptionSettingsList.isEmpty else {
            return nil
        }

        let cacheKey = createCacheKey(from: accountId, chainId: chain.chainId)

        let requests = subscriptionSettingsList.map(\.request)
        let handlersStore = subscriptionSettingsList.reduce(
            into: [String: RemoteSubscriptionHandlingFactoryProtocol]()
        ) { accum, settings in
            accum[settings.request.localKey] = settings.handlingFactory
        }

        let handlingFactory = BalanceRemoteSubscriptionHandlingProxy(store: handlersStore)

        return attachToSubscription(
            with: requests,
            chainId: chain.chainId,
            cacheKey: cacheKey,
            queue: queue,
            closure: closure,
            subscriptionHandlingFactory: handlingFactory
        )
    }

    func detachFromBalances(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        let cacheKey = createCacheKey(from: accountId, chainId: chainId)
        detachFromSubscription(cacheKey, subscriptionId: subscriptionId, queue: queue, closure: closure)
    }

    func attachToAssetBalance(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        let subscriptionSettingsList = prepareSubscriptionRequests(
            from: accountId,
            chainAsset: chainAsset,
            transactionSubscription: nil
        )

        guard !subscriptionSettingsList.isEmpty else {
            return nil
        }

        let cacheKey = createCacheKey(from: accountId, chainAssetId: chainAsset.chainAssetId)

        let requests = subscriptionSettingsList.map(\.request)
        let handlersStore = subscriptionSettingsList.reduce(
            into: [String: RemoteSubscriptionHandlingFactoryProtocol]()
        ) { accum, settings in
            accum[settings.request.localKey] = settings.handlingFactory
        }

        let handlingFactory = BalanceRemoteSubscriptionHandlingProxy(store: handlersStore)

        return attachToSubscription(
            with: requests,
            chainId: chainAsset.chain.chainId,
            cacheKey: cacheKey,
            queue: queue,
            closure: closure,
            subscriptionHandlingFactory: handlingFactory
        )
    }

    func detachFromAssetBalance(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainAssetId: ChainAssetId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        let cacheKey = createCacheKey(from: accountId, chainAssetId: chainAssetId)
        detachFromSubscription(cacheKey, subscriptionId: subscriptionId, queue: queue, closure: closure)
    }
}
