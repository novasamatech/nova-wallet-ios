import Foundation

extension StakingParachainInteractor {
    func performPriceSubscription() {
        guard let priceId = selectedChainAsset.asset.priceId else {
            presenter?.didReceivePrice(nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func performAssetBalanceSubscription() {
        let chainAssetId = selectedChainAsset.chainAssetId

        guard let accountId = selectedAccount?.chainAccount.accountId else {
            presenter?.didReceiveAssetBalance(nil)
            return
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }

    func performDelegatorSubscription() {
        let chainId = selectedChainAsset.chain.chainId

        guard let accountId = selectedAccount?.chainAccount.accountId else {
            presenter?.didReceiveDelegator(nil)
            return
        }

        delegatorProvider = subscribeToDelegatorState(
            for: chainId,
            accountId: accountId
        )
    }

    func performBlockNumberSubscription() {
        let chainId = selectedChainAsset.chain.chainId

        blockNumberProvider = subscribeToBlockNumber(for: chainId)
    }

    func performRoundInfoSubscription() {
        let chainId = selectedChainAsset.chain.chainId

        roundInfoProvider = subscribeToRound(for: chainId)
    }

    func performTotalRewardSubscription() {
        clear(singleValueProvider: &totalRewardProvider)

        if
            let address = selectedAccount?.chainAccount.toChecksumedAddress(),
            let rewardApi = selectedChainAsset.chain.externalApis?.stakingRewards() {
            totalRewardProvider = subscribeTotalReward(
                for: address,
                startTimestamp: totalRewardInterval?.startTimestamp,
                endTimestamp: totalRewardInterval?.endTimestamp,
                api: rewardApi,
                assetPrecision: Int16(selectedChainAsset.asset.precision)
            )
        } else {
            presenter?.didReceiveTotalReward(nil)
        }
    }

    func performYieldBoostTasksSubscription() {
        guard
            yieldBoostSupport.checkSupport(for: selectedChainAsset),
            let accountId = selectedAccount?.chainAccount.accountId else {
            presenter?.didReceiveYieldBoost(state: .unsupported)
            return
        }

        yieldBoostTasksProvider = subscribeYieldBoostTasks(
            for: selectedChainAsset.chainAssetId,
            accountId: accountId
        )
    }
}

extension StakingParachainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if selectedChainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceivePrice(priceData)
            case let .failure(error):
                presenter?.didReceiveError(error)
            }
        }
    }
}

extension StakingParachainInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == selectedChainAsset.chain.chainId,
            assetId == selectedChainAsset.asset.assetId,
            accountId == selectedAccount?.chainAccount.accountId else {
            return
        }

        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension StakingParachainInteractor: ParastakingLocalStorageSubscriber,
    ParastakingLocalStorageHandler {
    func handleParastakingRound(result: Result<ParachainStaking.RoundInfo?, Error>, for chainId: ChainModel.Id) {
        guard selectedChainAsset.chain.chainId == chainId else {
            return
        }

        switch result {
        case let .success(roundInfo):
            presenter?.didReceiveRoundInfo(roundInfo)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }

    func handleParastakingDelegatorState(
        result: Result<ParachainStaking.Delegator?, Error>,
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) {
        guard
            chainId == selectedChainAsset.chain.chainId,
            selectedAccount?.chainAccount.accountId == accountId else {
            return
        }

        switch result {
        case let .success(delegator):
            presenter?.didReceiveDelegator(delegator)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }

    func handleParastakingScheduledRequests(
        result: Result<[ParachainStaking.DelegatorScheduledRequest]?, Error>,
        for chainId: ChainModel.Id,
        delegatorId: AccountId
    ) {
        guard
            chainId == selectedChainAsset.chain.chainId,
            selectedAccount?.chainAccount.accountId == delegatorId else {
            return
        }

        switch result {
        case let .success(requests):
            presenter?.didReceiveScheduledRequests(requests)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension StakingParachainInteractor: StakingRewardsLocalSubscriber, StakingRewardsLocalHandler {
    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        for address: AccountAddress,
        api _: LocalChainExternalApi
    ) {
        guard selectedAccount?.chainAccount.toChecksumedAddress() == address else {
            return
        }

        switch result {
        case let .success(reward):
            presenter?.didReceiveTotalReward(reward)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension StakingParachainInteractor: ParaStkYieldBoostStorageSubscriber, ParaStkYieldBoostSubscriptionHandler {
    func handleYieldBoostTasks(
        result: Result<[ParaStkYieldBoostState.Task]?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    ) {
        guard selectedChainAsset.chain.chainId == chainId, selectedAccount?.chainAccount.accountId == accountId else {
            return
        }

        switch result {
        case let .success(tasks):
            presenter?.didReceiveYieldBoost(state: .supported(tasks: tasks ?? []))
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension StakingParachainInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    ) {
        guard selectedChainAsset.chain.chainId == chainId else {
            return
        }

        switch result {
        case let .success(blockNumber):
            presenter?.didReceiveBlockNumber(blockNumber)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension StakingParachainInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = selectedChainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
