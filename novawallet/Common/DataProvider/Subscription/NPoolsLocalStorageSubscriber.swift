import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol NPoolsLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol { get }

    var npoolsLocalSubscriptionHandler: NPoolsLocalSubscriptionHandler { get }

    func subscribePoolMember(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedPoolMember>?

    func subscribeDelegatedStaking(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedDelegatedStakingDelegator>?

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

    func subscribeLastPoolId(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedPoolId>?

    func subscribeMaxPoolMembers(for chainId: ChainModel.Id)
        -> AnyDataProvider<DecodedU32>?

    func subscribeCounterForPoolMembers(for chainId: ChainModel.Id)
        -> AnyDataProvider<DecodedU32>?

    func subscribeMaxPoolMembersPerPool(for chainId: ChainModel.Id)
        -> AnyDataProvider<DecodedU32>?

    func subscribeClaimableRewards(
        for chainId: ChainModel.Id,
        poolId: NominationPools.PoolId,
        accountId: AccountId
    ) -> AnySingleValueProvider<String>?

    func subscribePoolTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: Set<LocalChainExternalApi>,
        assetPrecision: Int16
    ) -> AnySingleValueProvider<TotalRewardItem>?
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

    func subscribeDelegatedStaking(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedDelegatedStakingDelegator>? {
        guard
            let provider = try? npoolsLocalSubscriptionFactory.getDelegatedStakingDelegatorProvider(
                for: accountId,
                chainId: chainId
            ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleDelegatedStaking(
                    result: .success(value),
                    accountId: accountId,
                    chainId: chainId
                )
            },
            failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleDelegatedStaking(
                    result: .failure(error),
                    accountId: accountId,
                    chainId: chainId
                )
            }
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

    func subscribeLastPoolId(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedPoolId>? {
        subscribeLastPoolId(for: chainId, callbackQueue: .main)
    }

    func subscribeLastPoolId(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedPoolId>? {
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
            },
            callbackQueue: callbackQueue,
            options: .init(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)
        )

        return provider
    }

    func subscribeMaxPoolMembers(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedU32>? {
        guard let provider = try? npoolsLocalSubscriptionFactory.getMaxPoolMembers(
            for: chainId,
            missingEntryStrategy: .defaultValue(StringScaleMapper(value: UInt32.max))
        ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleMaxPoolMembers(
                    result: .success(value?.value),
                    chainId: chainId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleMaxPoolMembers(
                    result: .failure(error),
                    chainId: chainId
                )
            }
        )

        return provider
    }

    func subscribeCounterForPoolMembers(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedU32>? {
        guard let provider = try? npoolsLocalSubscriptionFactory.getCounterForPoolMembers(
            for: chainId,
            missingEntryStrategy: .defaultValue(StringScaleMapper(value: 0))
        ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleCounterForPoolMembers(
                    result: .success(value?.value),
                    chainId: chainId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleCounterForPoolMembers(
                    result: .failure(error),
                    chainId: chainId
                )
            }
        )

        return provider
    }

    func subscribeMaxPoolMembersPerPool(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedU32>? {
        guard let provider = try? npoolsLocalSubscriptionFactory.getMaxMembersPerPool(
            for: chainId,
            missingEntryStrategy: .defaultValue(StringScaleMapper(value: UInt32.max))
        ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleMaxPoolMembersPerPool(
                    result: .success(value?.value),
                    chainId: chainId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleMaxPoolMembersPerPool(
                    result: .failure(error),
                    chainId: chainId
                )
            }
        )

        return provider
    }

    func subscribeClaimableRewards(
        for chainId: ChainModel.Id,
        poolId: NominationPools.PoolId,
        accountId: AccountId
    ) -> AnySingleValueProvider<String>? {
        guard
            let provider = try? npoolsLocalSubscriptionFactory.getClaimableRewards(
                for: chainId,
                accountId: accountId
            ) else {
            return nil
        }

        addSingleValueProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                let amount = value.flatMap { BigUInt($0) }

                self?.npoolsLocalSubscriptionHandler.handleClaimableRewards(
                    result: .success(amount),
                    chainId: chainId,
                    poolId: poolId,
                    accountId: accountId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleClaimableRewards(
                    result: .failure(error),
                    chainId: chainId,
                    poolId: poolId,
                    accountId: accountId
                )
            }
        )

        return provider
    }

    func subscribePoolTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: Set<LocalChainExternalApi>,
        assetPrecision: Int16
    ) -> AnySingleValueProvider<TotalRewardItem>? {
        guard let provider = try? npoolsLocalSubscriptionFactory.getTotalReward(
            for: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            api: api,
            assetPrecision: assetPrecision
        ) else {
            return nil
        }

        addSingleValueProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.handlePoolTotalReward(
                    result: .success(value),
                    for: address,
                    startTimestamp: startTimestamp,
                    endTimestamp: endTimestamp,
                    api: api
                )
            }, failureClosure: { [weak self] error in
                self?.handlePoolTotalReward(
                    result: .failure(error),
                    for: address,
                    startTimestamp: startTimestamp,
                    endTimestamp: endTimestamp,
                    api: api
                )
            }
        )

        return provider
    }
}
