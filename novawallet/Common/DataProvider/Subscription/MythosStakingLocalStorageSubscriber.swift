import Foundation
import Operation_iOS

protocol MythosStakingLocalStorageSubscriber: LocalStorageProviderObserving {
    var stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol { get }

    var stakingLocalSubscriptionHandler: MythosStakingLocalStorageHandler { get }

    func subscribeToMinStake(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedBigUInt>?

    func subscribeToCurrentSession(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedU32>?

    func subscribeToUserState(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<MythosStakingPallet.DecodedUserStake>?

    func subscribeToReleaseQueue(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<MythosStakingPallet.DecodedReleaseQueue>?

    func subscribeToAutoCompound(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<DecodedPercent>?

    func subscribeToCollatorRewardsPercentage(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedPercent>?

    func subscribeToExtraReward(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedBigUInt>?
}

extension MythosStakingLocalStorageSubscriber {
    func subscribeToMinStake(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBigUInt>? {
        subscribeToMinStake(for: chainId, callbackQueue: .main)
    }

    func subscribeToMinStake(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedBigUInt>? {
        guard let provider = try? stakingLocalSubscriptionFactory.getMinStakeProvider(for: chainId) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] valueMapper in
                self?.stakingLocalSubscriptionHandler.handleMinStake(
                    result: .success(valueMapper?.value),
                    chainId: chainId
                )
            },
            failureClosure: { [weak self] error in
                self?.stakingLocalSubscriptionHandler.handleMinStake(
                    result: .failure(error),
                    chainId: chainId
                )
            },
            callbackQueue: callbackQueue,
            options: DataProviderObserverOptions()
        )

        return provider
    }

    func subscribeToCurrentSession(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedU32>? {
        subscribeToCurrentSession(
            for: chainId,
            callbackQueue: .main
        )
    }

    func subscribeToCurrentSession(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedU32>? {
        guard let provider = try? stakingLocalSubscriptionFactory.getCurrentSessionProvider(for: chainId) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] valueMapper in
                self?.stakingLocalSubscriptionHandler.handleCurrentSession(
                    result: .success(valueMapper?.value),
                    chainId: chainId
                )
            },
            failureClosure: { [weak self] error in
                self?.stakingLocalSubscriptionHandler.handleCurrentSession(
                    result: .failure(error),
                    chainId: chainId
                )
            },
            callbackQueue: callbackQueue,
            options: DataProviderObserverOptions()
        )

        return provider
    }

    func subscribeToUserState(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<MythosStakingPallet.DecodedUserStake>? {
        guard let provider = try? stakingLocalSubscriptionFactory.getUserStakeProvider(
            for: chainId,
            accountId: accountId
        ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.stakingLocalSubscriptionHandler.handleUserStake(
                    result: .success(value),
                    chainId: chainId,
                    accountId: accountId
                )
            },
            failureClosure: { [weak self] error in
                self?.stakingLocalSubscriptionHandler.handleUserStake(
                    result: .failure(error),
                    chainId: chainId,
                    accountId: accountId
                )
            }
        )

        return provider
    }

    func subscribeToReleaseQueue(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<MythosStakingPallet.DecodedReleaseQueue>? {
        guard let provider = try? stakingLocalSubscriptionFactory.getReleaseQueueProvider(
            for: chainId,
            accountId: accountId
        ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.stakingLocalSubscriptionHandler.handleReleaseQueue(
                    result: .success(value),
                    chainId: chainId,
                    accountId: accountId
                )
            },
            failureClosure: { [weak self] error in
                self?.stakingLocalSubscriptionHandler.handleReleaseQueue(
                    result: .failure(error),
                    chainId: chainId,
                    accountId: accountId
                )
            }
        )

        return provider
    }

    func subscribeToAutoCompound(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) -> AnyDataProvider<DecodedPercent>? {
        guard let provider = try? stakingLocalSubscriptionFactory.getAutoCompoundProvider(
            for: chainId,
            accountId: accountId
        ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] decodedValue in
                self?.stakingLocalSubscriptionHandler.handleAutoCompound(
                    result: .success(decodedValue?.value),
                    chainId: chainId,
                    accountId: accountId
                )
            },
            failureClosure: { [weak self] error in
                self?.stakingLocalSubscriptionHandler.handleAutoCompound(
                    result: .failure(error),
                    chainId: chainId,
                    accountId: accountId
                )
            }
        )

        return provider
    }

    func subscribeToCollatorRewardsPercentage(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedPercent>? {
        guard let provider = try? stakingLocalSubscriptionFactory.getCollatorRewardsPercentageProvider(
            for: chainId
        ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] valueMapper in
                self?.stakingLocalSubscriptionHandler.handleCollatorRewardsPercentage(
                    result: .success(valueMapper?.value),
                    chainId: chainId
                )
            },
            failureClosure: { [weak self] error in
                self?.stakingLocalSubscriptionHandler.handleCollatorRewardsPercentage(
                    result: .failure(error),
                    chainId: chainId
                )
            },
            callbackQueue: callbackQueue,
            options: DataProviderObserverOptions()
        )

        return provider
    }

    func subscribeToExtraReward(
        for chainId: ChainModel.Id,
        callbackQueue: DispatchQueue
    ) -> AnyDataProvider<DecodedBigUInt>? {
        guard let provider = try? stakingLocalSubscriptionFactory.getExtraRewardProvider(
            for: chainId
        ) else {
            return nil
        }

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] valueMapper in
                self?.stakingLocalSubscriptionHandler.handleExtraReward(
                    result: .success(valueMapper?.value),
                    chainId: chainId
                )
            },
            failureClosure: { [weak self] error in
                self?.stakingLocalSubscriptionHandler.handleExtraReward(
                    result: .failure(error),
                    chainId: chainId
                )
            },
            callbackQueue: callbackQueue,
            options: DataProviderObserverOptions()
        )

        return provider
    }
}

extension MythosStakingLocalStorageSubscriber where Self: MythosStakingLocalStorageHandler {
    var stakingLocalSubscriptionHandler: MythosStakingLocalStorageHandler { self }
}
