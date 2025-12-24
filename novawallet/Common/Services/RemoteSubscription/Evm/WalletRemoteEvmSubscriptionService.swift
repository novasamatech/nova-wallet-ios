import Foundation
import Operation_iOS

struct RemoteEvmSubscriptionInfo {
    let accountId: AccountId
    let chain: ChainModel
    let assets: Set<AssetModel.Id>
}

struct RemoteEvmNativeSubscriptionInfo {
    let accountId: AccountId
    let chain: ChainModel
    let assetId: AssetModel.Id
}

protocol WalletRemoteEvmSubscriptionServiceProtocol {
    func attachERC20Balance(
        for info: RemoteEvmSubscriptionInfo,
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

    func attachNativeBalance(
        for info: RemoteEvmNativeSubscriptionInfo,
        transactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol?,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachNativeBalance(
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

    private func createNativeCacheKey(for chainId: ChainModel.Id, accountId: AccountId) -> String {
        "native" + "-" + chainId + "-" + accountId.toHex()
    }

    func attachERC20Balance(
        for info: RemoteEvmSubscriptionInfo,
        transactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol?,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        let chain = info.chain
        let accountId = info.accountId
        let cacheKey = createERC20CacheKey(for: chain.chainId, accountId: accountId)

        guard let holder = try? accountId.toAddress(using: chain.chainFormat) else {
            let error = AccountAddressConversionError.invalidEthereumAddress
            dispatchInQueueWhenPossible(queue) { closure?(.failure(error)) }
            return nil
        }

        let assetContracts: [EvmAssetContractId] = chain.assets.compactMap { asset in
            guard let contractAddress = asset.evmContractAddress, info.assets.contains(asset.assetId) else {
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
            let transactionHistoryUpdater = transactionHistoryUpdaterFactory?.createCustomAssetHistoryUpdater(
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
                request: .erc20Balance(request),
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

    func attachNativeBalance(
        for info: RemoteEvmNativeSubscriptionInfo,
        transactionHistoryUpdaterFactory: EvmTransactionHistoryUpdaterFactoryProtocol?,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        let chain = info.chain
        let accountId = info.accountId
        let cacheKey = createNativeCacheKey(for: chain.chainId, accountId: accountId)

        guard let holder = try? accountId.toAddress(using: chain.chainFormat) else {
            let error = AccountAddressConversionError.invalidEthereumAddress
            dispatchInQueueWhenPossible(queue) { closure?(.failure(error)) }
            return nil
        }

        do {
            let transactionUpdater = try transactionHistoryUpdaterFactory?.createNativeAssetHistoryUpdater(
                for: info.accountId,
                chainAssetId: ChainAssetId(chainId: info.chain.chainId, assetId: info.assetId)
            )

            let request = EvmNativeBalanceSubscriptionRequest(
                holder: holder,
                assetId: info.assetId,
                transactionHistoryUpdater: transactionUpdater
            )

            return try attachToSubscription(
                on: chain.chainId,
                request: .native(request),
                cacheKey: cacheKey,
                queue: queue,
                closure: closure
            )
        } catch {
            dispatchInQueueWhenPossible(queue) { closure?(.failure(error)) }
            return nil
        }
    }

    func detachNativeBalance(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        let cacheKey = createNativeCacheKey(for: chainId, accountId: accountId)

        detachFromSubscription(cacheKey, subscriptionId: subscriptionId, queue: queue, closure: closure)
    }
}
