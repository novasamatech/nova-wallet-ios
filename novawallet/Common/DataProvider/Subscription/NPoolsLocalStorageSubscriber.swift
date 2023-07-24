import Foundation
import RobinHood

protocol NPoolsLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol { get }

    var npoolsLocalSubscriptionHandler: NPoolsLocalSubscriptionHandler { get }

    func subscribePoolMember(
        for accountId: AccountId,
        chainId: ChainModel.Id
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
    ) -> AnyDataProvider<NominationPools.RewardPool>?

    func subscribeSubPools(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<NominationPools.SubPools>?

    func subscribeMinJoinBond(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedBigUInt>?

    func subscribeLastPoolId(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedU32>?
}

extension NPoolsLocalStorageSubscriber where Self: NPoolsLocalSubscriptionHandler {
    var npoolsLocalSubscriptionHandler: NPoolsLocalSubscriptionHandler { self }

    func subscribePoolMember(
        for accountId: AccountId,
        chainId: ChainModel.Id
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
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handlePoolMember(
                    result: .failure(error),
                    accountId: accountId,
                    chainId: chainId
                )
            }
        )
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
                    result: .success(value),
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
    }

    func subscribeRewardPool(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<NominationPools.RewardPool>? {
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
    }

    func subscribeSubPools(
        for poolId: NominationPools.PoolId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<NominationPools.SubPools>? {
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
    }

    func subscribeMinJoinBond(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedBigUInt>? {
        guard let provider = try? npoolsLocalSubscriptionFactory.getMinJoinBondProvider(for: chainId) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleMinJoinBond(
                    result: .success(value),
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
    }

    func subscribeLastPoolId(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedU32>? {
        guard let provider = try npoolsLocalSubscriptionFactory.getLastPoolIdProvider(for: chainId) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.npoolsLocalSubscriptionHandler.handleLastPoolId(
                    result: .success(value),
                    chainId: chainId
                )
            }, failureClosure: { [weak self] error in
                self?.npoolsLocalSubscriptionHandler.handleLastPoolId(
                    result: .failure(error),
                    chainId: chainId
                )
            }
        )
    }
}
