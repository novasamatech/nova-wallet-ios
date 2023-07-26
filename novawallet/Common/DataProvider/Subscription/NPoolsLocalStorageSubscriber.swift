import Foundation
import RobinHood

protocol NPoolsLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol { get }

    var npoolsLocalSubscriptionHandler: NPoolsLocalSubscriptionHandler { get }

    func subscribePoolMember(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedPoolMember>?

    func subscribeBondedPool(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBondedPool>?

    func subscribePoolMetadata(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBytes>?

    func subscribeRewardPool(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedRewardPool>?

    func subscribeSubPools(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedSubPools>?

    func subscribeMinJoinBond(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedBigUInt>?

    func subscribeLastPoolId(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedU32>?
}

extension NPoolsLocalStorageSubscriber where Self: NPoolsLocalSubscriptionHandler {
    var npoolsLocalSubscriptionHandler: NPoolsLocalSubscriptionHandler { self }

    func subscribePoolMember(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedPoolMember>? {
        subscribePoolMember(for: accountId, chainId: chainId, callbackQueue: .main)
    }

    func subscribePoolMember(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedPoolMember>? {
        guard
            let provider = try? npoolsLocalSubscriptionFactory.getPoolMemberProvider(
                for: accountId,
                chainId: chainId
            ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handlePoolMember(
                    result: .success(value),
                    accountId: accountId,
                    chainId: chainId
                )
            },
            failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handlePoolMember(
                    result: .failure(error),
                    accountId: accountId,
                    chainId: chainId
                )
            },
            callbackQueue: callbackQueue,
            options: .init(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)
        )

        return provider
    }

    func subscribeBondedPool(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBondedPool>? {
        guard
            let provider = try? npoolsLocalSubscriptionFactory.getBondedPoolProvider(
                for: poolId,
                chainId: chainId
            ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleBondedPool(
                    result: .success(value),
                    poolId: poolId,
                    chainId: chainId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleBondedPool(
                    result: .failure(error),
                    poolId: poolId,
                    chainId: chainId
                )
            }
        )

        return provider
    }

    func subscribePoolMetadata(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBytes>? {
        guard
            let provider = try? npoolsLocalSubscriptionFactory.getMetadataProvider(
                for: poolId,
                chainId: chainId
            ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handlePoolMetadata(
                    result: .success(value?.wrappedValue),
                    poolId: poolId,
                    chainId: chainId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handlePoolMetadata(
                    result: .failure(error),
                    poolId: poolId,
                    chainId: chainId
                )
            }
        )

        return provider
    }

    func subscribeRewardPool(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedRewardPool>? {
        guard
            let provider = try? npoolsLocalSubscriptionFactory.getRewardPoolProvider(
                for: poolId,
                chainId: chainId
            ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleRewardPool(
                    result: .success(value),
                    poolId: poolId,
                    chainId: chainId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleRewardPool(
                    result: .failure(error),
                    poolId: poolId,
                    chainId: chainId
                )
            }
        )

        return provider
    }

    func subscribeSubPools(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedSubPools>? {
        guard
            let provider = try? npoolsLocalSubscriptionFactory.getSubPoolsProvider(
                for: poolId,
                chainId: chainId
            ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleSubPools(
                    result: .success(value),
                    poolId: poolId,
                    chainId: chainId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleSubPools(
                    result: .failure(error),
                    poolId: poolId,
                    chainId: chainId
                )
            }
        )

        return provider
    }

    func subscribeMinJoinBond(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedBigUInt>? {
        guard let provider = try? npoolsLocalSubscriptionFactory.getMinJoinBondProvider(for: chainId) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleMinJoinBond(
                    result: .success(value?.value),
                    chainId: chainId
                )
            },
            failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleMinJoinBond(
                    result: .failure(error),
                    chainId: chainId
                )
            }
        )

        return provider
    }

    func subscribeLastPoolId(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedU32>? {
        guard let provider = try? npoolsLocalSubscriptionFactory.getLastPoolIdProvider(for: chainId) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleLastPoolId(
                    result: .success(value?.value),
                    chainId: chainId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleLastPoolId(
                    result: .failure(error),
                    chainId: chainId
                )
            }
        )

        return provider
    }
}
