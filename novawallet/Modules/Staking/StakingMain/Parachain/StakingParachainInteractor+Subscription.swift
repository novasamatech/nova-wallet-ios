import Foundation

extension StakingParachainInteractor {
    func clearChainRemoteSubscription(for chainId: ChainModel.Id) {
        if let chainSubscriptionId = chainSubscriptionId {
            stakingAssetSubscriptionService.detachFromGlobalData(
                for: chainSubscriptionId,
                chainId: chainId,
                queue: nil,
                closure: nil
            )

            self.chainSubscriptionId = nil
        }
    }

    func setupChainRemoteSubscription() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        chainSubscriptionId = stakingAssetSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        )
    }

    func clearAccountRemoteSubscription() {
        if
            let accountSubscriptionId = accountSubscriptionId,
            let chainId = selectedChainAsset?.chain.chainId,
            let accountId = selectedAccount?.chainAccount.accountId {
            stakingAccountSubscriptionService.detachFromAccountData(
                for: accountSubscriptionId,
                chainId: chainId,
                accountId: accountId,
                queue: nil,
                closure: nil
            )

            self.accountSubscriptionId = nil
        }
    }

    func setupAccountRemoteSubscription() {
        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let accountId = selectedAccount?.chainAccount.accountId else {
            return
        }

        accountSubscriptionId = stakingAccountSubscriptionService.attachToAccountData(
            for: chainId,
            accountId: accountId,
            queue: nil,
            closure: nil
        )
    }

    func performPriceSubscription() {
        guard let chainAsset = selectedChainAsset else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceivePrice(nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId)
    }

    func performAssetBalanceSubscription() {
        guard let chainAssetId = selectedChainAsset?.chainAssetId else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

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
        guard let chainId = selectedChainAsset?.chain.chainId else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

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
        guard let chainId = selectedChainAsset?.chain.chainId else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

        blockNumberProvider = subscribeToBlockNumber(for: chainId)
    }

    func performRoundInfoSubscription() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

        roundInfoProvider = subscribeToRound(for: chainId)
    }

    func performTotalRewardSubscription() {
        guard let chainAsset = selectedChainAsset else {
            presenter?.didReceiveError(PersistentValueSettingsError.missingValue)
            return
        }

        if
            let address = selectedAccount?.chainAccount.toChecksumedAddress(),
            let rewardApi = chainAsset.chain.externalApi?.staking {
            totalRewardProvider = subscribeTotalReward(
                for: address,
                api: rewardApi,
                assetPrecision: Int16(chainAsset.asset.precision)
            )
        } else {
            presenter?.didReceiveTotalReward(nil)
        }
    }
}

extension StakingParachainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if let chainAsset = selectedChainAsset, chainAsset.asset.priceId == priceId {
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
            chainId == selectedChainAsset?.chain.chainId,
            assetId == selectedChainAsset?.asset.assetId,
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
        guard selectedChainAsset?.chain.chainId == chainId else {
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
            chainId == selectedChainAsset?.chain.chainId,
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
            chainId == selectedChainAsset?.chain.chainId,
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

    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        for address: AccountAddress,
        api _: ChainModel.ExternalApi
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

extension StakingParachainInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    ) {
        guard selectedChainAsset?.chain.chainId == chainId else {
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
