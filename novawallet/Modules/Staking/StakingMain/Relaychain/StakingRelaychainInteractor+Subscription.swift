import Foundation
import Operation_iOS
import BigInt

extension StakingRelaychainInteractor {
    func handle(stashItem: StashItem?) {
        self.stashItem = stashItem

        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &bagListNodeProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &validatorProvider)
        clear(dataProvider: &payeeProvider)
        clear(streamableProvider: &controllerAccountProvider)
        clear(streamableProvider: &stashAccountProvider)
        clear(dataProvider: &proxyProvider)

        if
            let stashItem = stashItem,
            let chainAsset = selectedChainAsset,
            let stashAccountId = try? stashItem.stash.toAccountId(),
            let controllerId = try? stashItem.controller.toAccountId() {
            let chainId = chainAsset.chain.chainId
            ledgerProvider = subscribeLedgerInfo(for: controllerId, chainId: chainId)
            bagListNodeProvider = subscribeBagListNode(for: stashAccountId, chainId: chainId)
            nominatorProvider = subscribeNomination(for: stashAccountId, chainId: chainId)
            validatorProvider = subscribeValidator(for: stashAccountId, chainId: chainId)
            payeeProvider = subscribePayee(for: stashAccountId, chainId: chainId)

            performTotalRewardSubscription()

            subscribeToControllerAccount(address: stashItem.controller, chain: chainAsset.chain)

            if stashItem.controller != stashItem.stash {
                subscribeToStashAccount(address: stashItem.stash, chain: chainAsset.chain)
            }

            if let accountId = selectedAccount?.accountId, chainAsset.chain.hasProxy {
                proxyProvider = subscribeProxies(
                    for: accountId,
                    chainId: chainId,
                    modifyInternalList: ProxyFilter.filteredStakingProxy
                )
            }
        }

        presenter?.didReceive(stashItem: stashItem)
    }

    func performTotalRewardSubscription() {
        clear(singleValueProvider: &totalRewardProvider)
        if
            let stashItem = stashItem,
            let chainAsset = selectedChainAsset {
            if let rewardApi = chainAsset.chain.externalApis?.stakingRewards() {
                totalRewardProvider = subscribeTotalReward(
                    for: stashItem.stash,
                    startTimestamp: totalRewardInterval?.startTimestamp,
                    endTimestamp: totalRewardInterval?.endTimestamp,
                    api: rewardApi,
                    assetPrecision: Int16(chainAsset.asset.precision)
                )
            } else {
                let zeroReward = TotalRewardItem(
                    address: stashItem.stash,
                    amount: AmountDecimal(value: 0)
                )
                presenter?.didReceive(totalReward: zeroReward)
            }
        }
    }

    func performPriceSubscription() {
        let chainAsset = stakingOption.chainAsset

        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func performAccountInfoSubscription() {
        guard let selectedAccount = selectedWalletSettings.value else {
            presenter?.didReceive(balanceError: PersistentValueSettingsError.missingValue)
            return
        }

        let chainAsset = stakingOption.chainAsset

        guard let accountResponse = selectedAccount.fetch(
            for: chainAsset.chain.accountRequest()
        ) else {
            presenter?.didReceive(assetBalance: nil)
            return
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountResponse.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func clearStashControllerSubscription() {
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &bagListNodeProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &validatorProvider)
        clear(singleValueProvider: &totalRewardProvider)
        clear(dataProvider: &payeeProvider)
        clear(streamableProvider: &stashControllerProvider)
        clear(dataProvider: &proxyProvider)
    }

    func performStashControllerSubscription() {
        guard let address = selectedAccount?.toAddress(), let chain = selectedChainAsset?.chain else {
            handle(stashItem: nil)
            return
        }

        stashControllerProvider = subscribeStashItemProvider(for: address, chainId: chain.chainId)
    }

    func subscribeToControllerAccount(address: AccountAddress, chain: ChainModel) {
        guard controllerAccountProvider == nil, let accountId = try? address.toAccountId() else {
            return
        }

        controllerAccountProvider = subscribeForAccountId(accountId, chain: chain)
    }

    func subscribeToStashAccount(address: AccountAddress, chain: ChainModel) {
        guard stashAccountProvider == nil, let accountId = try? address.toAccountId() else {
            return
        }

        stashAccountProvider = subscribeForAccountId(accountId, chain: chain)
    }

    func performNominatorLimitsSubscription() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        minNominatorBondProvider = subscribeToMinNominatorBond(for: chainId)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainId)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainId)
    }

    func performBagListParamsSubscription() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        bagListSizeProvider = subscribeBagsListSize(for: chainId)
        totalIssuanceProvider = subscribeTotalIssuance(for: chainId)
    }
}

extension StakingRelaychainInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        switch result {
        case let .success(stashItem):
            handle(stashItem: stashItem)
            presenter?.didReceive(stashItem: stashItem)
        case let .failure(error):
            presenter?.didReceive(stashItemError: error)
        }
    }

    func handleLedgerInfo(
        result: Result<Staking.Ledger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(ledgerInfo):
            presenter?.didReceive(ledgerInfo: ledgerInfo)
        case let .failure(error):
            presenter?.didReceive(ledgerInfoError: error)
        }
    }

    func handleBagListNode(
        result: Result<BagList.Node?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter?.didReceiveBagListNode(result: result)
    }

    func handleNomination(
        result: Result<Staking.Nomination?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(nomination):
            presenter?.didReceive(nomination: nomination)
        case let .failure(error):
            presenter?.didReceive(nominationError: error)
        }
    }

    func handleValidator(
        result: Result<Staking.ValidatorPrefs?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(validatorPrefs):
            presenter?.didReceive(validatorPrefs: validatorPrefs)
        case let .failure(error):
            presenter?.didReceive(validatorError: error)
        }
    }

    func handlePayee(
        result: Result<Staking.RewardDestinationArg?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(payee):
            presenter?.didReceive(payee: payee)
        case let .failure(error):
            presenter?.didReceive(payeeError: error)
        }
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        presenter?.didReceiveMinNominatorBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter?.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter?.didReceiveMaxNominatorsCount(result: result)
    }

    func handleBagListSize(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter?.didReceiveBagListSize(result: result)
    }

    func handleTotalIssuance(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(totalIssuance):
            let scoreFactor = totalIssuance.map { BagList.scoreFactor(for: $0) }
            presenter?.didReceiveBagListScoreFactor(result: .success(scoreFactor))
        case let .failure(error):
            presenter?.didReceiveBagListScoreFactor(result: .failure(error))
        }
    }
}

extension StakingRelaychainInteractor: StakingRewardsLocalSubscriber, StakingRewardsLocalHandler {
    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        for _: AccountAddress,
        api _: Set<LocalChainExternalApi>
    ) {
        switch result {
        case let .success(totalReward):
            presenter?.didReceive(totalReward: totalReward)
        case let .failure(error):
            presenter?.didReceive(totalRewardError: error)
        }
    }
}

extension StakingRelaychainInteractor: ProxyListLocalStorageSubscriber, ProxyListLocalSubscriptionHandler {
    func handleProxies(result: Result<ProxyDefinition?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter?.didReceiveProxy(result: result)
    }
}

extension StakingRelaychainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if stakingOption.chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceive(price: priceData)
            case let .failure(error):
                presenter?.didReceive(priceError: error)
            }
        }
    }
}

extension StakingRelaychainInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            presenter?.didReceive(assetBalance: assetBalance)
        case let .failure(error):
            presenter?.didReceive(balanceError: error)
        }
    }
}

extension StakingRelaychainInteractor: AccountLocalSubscriptionHandler, AccountLocalStorageSubscriber {
    func handleAccountResponse(
        result: Result<MetaChainAccountResponse?, Error>,
        accountId: AccountId,
        chain _: ChainModel
    ) {
        switch result {
        case let .success(account):
            presenter?.didReceiveAccount(account, for: accountId)
        case .failure:
            presenter?.didReceiveAccount(nil, for: accountId)
        }
    }
}

extension StakingRelaychainInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        let chainAsset = stakingOption.chainAsset

        guard
            presenter != nil,
            let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
